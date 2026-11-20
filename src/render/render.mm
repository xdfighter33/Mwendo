#import <Cocoa/Cocoa.h>
#include "render.hpp"
#include "physics/physics.hpp"
#include <stdexcept>
#include <utility>

@interface CameraView : MTKView {
    BOOL _keys[4]; // W, A, S, D
    float _scrollMovement;
}
- (simd_float3)movement;
- (float)takeScrollMovement;
- (void)clearKeys;
@end

@implementation CameraView
- (BOOL)acceptsFirstResponder { return YES; }
- (void)clearKeys { for (BOOL &key : _keys) key = NO; }
- (void)keyDown:(NSEvent *)event {
    NSString *key = event.charactersIgnoringModifiers.lowercaseString;
    if (key.length != 1) { [super keyDown:event]; return; }
    switch ([key characterAtIndex:0]) {
        case 'w': _keys[0] = YES; break;
        case 'a': _keys[1] = YES; break;
        case 's': _keys[2] = YES; break;
        case 'd': _keys[3] = YES; break;
        default: [super keyDown:event]; break;
    }
}
- (void)keyUp:(NSEvent *)event {
    NSString *key = event.charactersIgnoringModifiers.lowercaseString;
    if (key.length != 1) { [super keyUp:event]; return; }
    switch ([key characterAtIndex:0]) {
        case 'w': _keys[0] = NO; break;
        case 'a': _keys[1] = NO; break;
        case 's': _keys[2] = NO; break;
        case 'd': _keys[3] = NO; break;
        default: [super keyUp:event]; break;
    }
}
- (void)scrollWheel:(NSEvent *)event {
    _scrollMovement += static_cast<float>(event.scrollingDeltaY) *
        (event.hasPreciseScrollingDeltas ? 0.012f : 0.2f);
}
- (simd_float3)movement {
    return {float(_keys[3] - _keys[1]), 0, float(_keys[2] - _keys[0])};
}
- (float)takeScrollMovement {
    float movement = _scrollMovement;
    _scrollMovement = 0;
    return movement;
}
@end


@interface FrameDelegate : NSObject <MTKViewDelegate, NSApplicationDelegate> {
@public
    render::FrameCallback callback;
}
@end
@implementation FrameDelegate
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}
- (void)drawInMTKView:(MTKView *)view {
    CameraView *input = (CameraView *)view;
    if (!view.window.isKeyWindow) [input clearKeys];
    callback(view, [input movement], [input takeScrollMovement]);
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
@end

namespace {
struct DrawMesh {
    id<MTLBuffer> indices;
    id<MTLBuffer> material;
    NSUInteger indexCount;
    std::vector<size_t> bodyIds;
};
struct CameraUniforms {
    simd_float4x4 viewProjection;
    simd_float4 cameraPosition;
};
}

struct render::Impl {
    id<MTLDevice> device;
    NSWindow *window;
    CameraView *view;
    FrameDelegate *delegate;
    id<MTLRenderPipelineState> pipeline;
    id<MTLDepthStencilState> depthState;
    std::vector<DrawMesh> meshes;
};

render::render(id<MTLDevice> device, id<MTLLibrary> library) : impl_(new Impl{}) {
    impl_->device = device;
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    NSRect frame = NSMakeRect(0, 0, 800, 600);
    impl_->window = [[NSWindow alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    impl_->window.releasedWhenClosed = NO;
    impl_->window.title = @"Metal Physics Engine";
    [impl_->window center];
    impl_->view = [[CameraView alloc] initWithFrame:frame device:device];
    impl_->view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    impl_->view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    impl_->view.clearColor = MTLClearColorMake(0.06, 0.08, 0.12, 1);
    impl_->view.clearDepth = 1.0;
    impl_->delegate = [FrameDelegate new];
    impl_->window.contentView = impl_->view;

    NSError *error = nil;
    MTLRenderPipelineDescriptor *descriptor = [MTLRenderPipelineDescriptor new];
    descriptor.vertexFunction = [library newFunctionWithName:@"physicsVertex"];
    descriptor.fragmentFunction = [library newFunctionWithName:@"cubeFragment"];
    descriptor.colorAttachments[0].pixelFormat = impl_->view.colorPixelFormat;
    descriptor.depthAttachmentPixelFormat = impl_->view.depthStencilPixelFormat;
    impl_->pipeline = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    [descriptor.vertexFunction release];
    [descriptor.fragmentFunction release];
    [descriptor release];
    MTLDepthStencilDescriptor *depth = [MTLDepthStencilDescriptor new];
    depth.depthCompareFunction = MTLCompareFunctionLess;
    depth.depthWriteEnabled = YES;
    impl_->depthState = [device newDepthStencilStateWithDescriptor:depth];
    [depth release];
    if (!impl_->pipeline || !impl_->depthState)
        throw std::runtime_error(error.localizedDescription.UTF8String ?: "Render setup failed");
}

render::~render() {
    impl_->view.delegate = nil;
    NSApp.delegate = nil;
    for (const DrawMesh& mesh : impl_->meshes) {
        [mesh.indices release];
        [mesh.material release];
    }
    [impl_->pipeline release];
    [impl_->depthState release];
    [impl_->delegate release];
    [impl_->window release];
    [impl_->view release];
    delete impl_;
}

void render::addMesh(const MeshData& mesh, uint32_t material, std::vector<size_t> bodyIds) {
    DrawMesh draw{};
    draw.bodyIds = std::move(bodyIds);
    draw.indexCount = mesh.indices.size();
    draw.indices = [impl_->device newBufferWithBytes:mesh.indices.data() length:mesh.indices.size() * sizeof(uint32_t) options:MTLResourceStorageModeShared];
    draw.material = [impl_->device newBufferWithBytes:&material length:sizeof(material) options:MTLResourceStorageModeShared];
    if (!draw.indices || !draw.material) {
        [draw.indices release]; [draw.material release];
        throw std::runtime_error("Could not create render buffers");
    }
    impl_->meshes.push_back(std::move(draw));
}

void render::encodeDraw(id<MTL4CommandBuffer> command, MTKView *view,
                        const PhysicsWorld& physics, const Camera& camera,
                        id<CAMetalDrawable> drawable, MTLRenderPassDescriptor *viewPass,
                        MTL4CommitOptions *completion) {
    CameraUniforms uniforms = {camera.viewProjection(view.drawableSize.width / view.drawableSize.height),
        {camera.position.x, camera.position.y, camera.position.z, 1}};
    id<MTLBuffer> cameraBuffer = [impl_->device newBufferWithBytes:&uniforms length:sizeof(uniforms) options:MTLResourceStorageModeShared];
    MTL4ArgumentTableDescriptor *tableDescriptor = [MTL4ArgumentTableDescriptor new];
    tableDescriptor.maxBufferBindCount = 4;
    id<MTL4ArgumentTable> table = [impl_->device newArgumentTableWithDescriptor:tableDescriptor error:nil];
    [tableDescriptor release];
    MTLResidencySetDescriptor *residencyDescriptor = [MTLResidencySetDescriptor new];
    id<MTLResidencySet> residency = [impl_->device newResidencySetWithDescriptor:residencyDescriptor error:nil];
    [residencyDescriptor release];
    if (!cameraBuffer || !table || !residency) {
        [cameraBuffer release]; [table release]; [residency release];
        throw std::runtime_error("Could not create render frame resources");
    }
    // Keep transient resources alive until the engine's submission completes.
    [completion addFeedbackHandler:^(id<MTL4CommitFeedback> feedback) {
        [cameraBuffer release]; [table release]; [residency release];
    }];
    [residency addAllocation:cameraBuffer];
    [residency addAllocation:drawable.texture];
    [residency addAllocation:view.depthStencilTexture];
    for (const DrawMesh& mesh : impl_->meshes) {
        [residency addAllocation:mesh.indices];
        [residency addAllocation:mesh.material];
        for (size_t id : mesh.bodyIds) {
            const PhysicsBody& body = physics.body(id);
            [residency addAllocation:body.positionBuffer()];
            [residency addAllocation:body.renderToParticleBuffer()];
        }
    }
    [residency commit];
    [command useResidencySet:residency];
    MTL4RenderPassDescriptor *pass = [MTL4RenderPassDescriptor new];
    pass.colorAttachments[0] = viewPass.colorAttachments[0];
    pass.depthAttachment = viewPass.depthAttachment;
    id<MTL4RenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
    [pass release];
    if (!encoder) return;
    [encoder setRenderPipelineState:impl_->pipeline];
    [encoder setDepthStencilState:impl_->depthState];
    [table setAddress:cameraBuffer.gpuAddress atIndex:2];
    [encoder setArgumentTable:table atStages:MTLRenderStageVertex | MTLRenderStageFragment];
    for (const DrawMesh& mesh : impl_->meshes) {
        [table setAddress:mesh.material.gpuAddress atIndex:3];
        for (size_t id : mesh.bodyIds) {
            const PhysicsBody& body = physics.body(id);
            [table setAddress:body.positionBuffer().gpuAddress atIndex:0];
            [table setAddress:body.renderToParticleBuffer().gpuAddress atIndex:1];
            [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:mesh.indexCount indexType:MTLIndexTypeUInt32 indexBuffer:mesh.indices.gpuAddress indexBufferLength:mesh.indexCount * sizeof(uint32_t)];
        }
    }
    [encoder endEncoding];
}

int render::run(FrameCallback callback) {
    impl_->delegate->callback = std::move(callback);
    impl_->view.delegate = impl_->delegate;
    NSApp.delegate = impl_->delegate;
    [impl_->window makeKeyAndOrderFront:nil];
    [impl_->window makeFirstResponder:impl_->view];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp run];
    impl_->view.delegate = nil;
    impl_->delegate->callback = {};
    return 0;
}

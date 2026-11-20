#include "Engine.hpp"
#include "render/render.hpp"
#include "physics/physics.hpp"
#import <QuartzCore/QuartzCore.h>
#include <algorithm>
#include <stdexcept>

namespace {
// Engine owns the GPU context and drains submissions before bodies are destroyed.
struct GPUContext {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    id<MTLLibrary> library = nil;
    id<MTL4CommandQueue> queue = nil;
    dispatch_group_t pending = dispatch_group_create();

    GPUContext() {
        if (!device) throw std::runtime_error("Metal is unavailable");
        NSString *base = [[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent];
        NSString *path = [base stringByAppendingPathComponent:@"assets/shaders/PhysicsShaders.metallib"];
        NSError *error = nil;
        library = [device newLibraryWithURL:[NSURL fileURLWithPath:path] error:&error];
        queue = [device newMTL4CommandQueue];
        if (!library || !queue)
            throw std::runtime_error(error.localizedDescription.UTF8String ?: "GPU setup failed");
    }
    void drain() { dispatch_group_wait(pending, DISPATCH_TIME_FOREVER); }
    ~GPUContext() {
        drain();
        [queue release]; [library release]; [device release];
        dispatch_release(pending);
    }
};
}

int Engine::run() {
    @autoreleasepool {
        if (@available(macOS 26.0, *)) {} else {
            NSLog(@"Metal 4 requires macOS 26 or later");
            return 1;
        }
        try {
            GPUContext gpu;
            Scene scene = Scene::demo();
            PhysicsWorld physics(gpu.device, gpu.library);
            render renderer(gpu.device, gpu.library);
            NSString *base = [[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent];
            for (const SceneObject& object : scene.objects) {
                if (object.instances.empty()) continue;
                NSString *name = [NSString stringWithUTF8String:object.meshFile.c_str()];
                NSString *path = [[base stringByAppendingPathComponent:@"assets/models"] stringByAppendingPathComponent:name];
                MeshData mesh = loadMesh(path.UTF8String);
                std::vector<size_t> bodyIds;
                for (const Transform& instance : object.instances)
                    bodyIds.push_back(physics.addBody(mesh, instance, object.inverseMass));
                renderer.addMesh(mesh, object.material, std::move(bodyIds));
            }
            CFTimeInterval lastFrame = CACurrentMediaTime();
            int result = renderer.run([&](MTKView *view, simd_float3 movement, float scroll) {
                @autoreleasepool {
                    CFTimeInterval now = CACurrentMediaTime();
                    float dt = static_cast<float>(std::min(now - lastFrame, 0.05));
                    lastFrame = now;
                    if (simd_length_squared(movement) > 0)
                        scene.camera.position += simd_normalize(movement) * (3.0f * dt);
                    scene.camera.position.z -= scroll;
                    id<CAMetalDrawable> drawable = view.currentDrawable;
                    MTLRenderPassDescriptor *pass = view.currentRenderPassDescriptor;
                    if (!drawable || !pass || view.drawableSize.height == 0) return;

                    id<MTL4CommandAllocator> allocator = [gpu.device newCommandAllocator];
                    id<MTL4CommandBuffer> command = [gpu.device newCommandBuffer];
                    MTL4CommitOptions *options = [MTL4CommitOptions new];
                    if (!allocator || !command || !options) {
                        [allocator release]; [command release]; [options release];
                        return;
                    }

                   // 1 allocate -> create encoders here -> done   
                    [command beginCommandBufferWithAllocator:allocator];

                    // Encode simulation here before rendering when its kernels are ready.
                    physics.encodeStep(command,dt,options);
                    renderer.encodeDraw(command, view, physics, scene.camera, drawable, pass, options);

                    [command endCommandBuffer];

                    dispatch_group_t pending = gpu.pending;
                    dispatch_group_enter(pending);
                    [options addFeedbackHandler:^(id<MTL4CommitFeedback> feedback) {
                        if (feedback.error) NSLog(@"Metal 4 command failed: %@", feedback.error);
                        [allocator release]; [command release];
                        dispatch_group_leave(pending);
                    }];
                    id<MTL4CommandBuffer> commands[] = {command};
                    [gpu.queue commit:commands count:1 options:options];
                    [options release];
                    [gpu.queue signalDrawable:drawable];
                    [drawable present];
                }
            });
            gpu.drain();
            return result;
        } catch (const std::exception& error) {
            NSLog(@"Engine setup failed: %s", error.what());
            return 1;
        }
    }
}

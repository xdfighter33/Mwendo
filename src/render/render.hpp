#pragma once
#import <MetalKit/MetalKit.h>
#include "mesh/mesh.hpp"
#include "scene/Scene.hpp"
#include <functional>
#include <vector>

class PhysicsWorld;

// Window/input callbacks and render encoding. Engine owns frame submission.
class render {
public:
    using FrameCallback = std::function<void(MTKView *, simd_float3, float)>;
    render(id<MTLDevice> device, id<MTLLibrary> library);
    ~render();
    render(const render&) = delete;
    render& operator=(const render&) = delete;
    void addMesh(const MeshData& mesh, uint32_t material, std::vector<size_t> bodyIds);
    void encodeDraw(id<MTL4CommandBuffer> command, MTKView *view,
                    const PhysicsWorld& physics, const Camera& camera,
                    id<CAMetalDrawable> drawable, MTLRenderPassDescriptor *viewPass,
                    MTL4CommitOptions *completion);
    int run(FrameCallback callback);
private:
    struct Impl;
    Impl *impl_;
};

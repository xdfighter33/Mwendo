#pragma once
#import <Metal/Metal.h>
#include "mesh/mesh.hpp"
#include "scene/Scene.hpp"
#include <deque>


class PhysicsBody {
public:
    PhysicsBody(id<MTLDevice> device, const MeshData& mesh, const Transform& transform, float inverseMass = 1.0f);
    ~PhysicsBody();
    PhysicsBody(const PhysicsBody &) = delete;
    PhysicsBody &operator=(const PhysicsBody &) = delete;

    void swapPositionBuffers() {
        std::swap(positionA_, positionB_);
    }

    id<MTLBuffer> positionBuffer() const { return positionA_; }

    id<MTLBuffer> predictedPositionBuffer() const {
        return positionB_; }
    id<MTLBuffer> Old_positionBuffer() const { return oldPosition_; }
    id<MTLBuffer> InverseMassBuffer() const { return inverseMass_; }
    id<MTLBuffer> renderToParticleBuffer() const {
        return renderToParticle_;
    }
    size_t particleCount() const {
        return positionA_.length / sizeof(simd_float3);
    }
private:
    /*
      id<MTLBuffer> pos_x = nil;
      id<MTLBuffer> pos_y = nil;
      id<MTLBuffer> pos_z = nil;
      id<MTLBuffer> old_pos_x = nil;
      id<MTLBuffer> old_pos_y = nil;
      id<MTLBuffer> old_pos_z = nil;
      id<MTLBuffer> vel_x = nil;
      id<MTLBuffer> vel_y = nil;
      id<MTLBuffer> vel_z = nil;

      id<MTLBuffer> Inverse_mass = nil

      */
    id<MTLBuffer> positionA_   = nil;
    id<MTLBuffer> positionB_   = nil;
    id<MTLBuffer> oldPosition_ = nil;
    id<MTLBuffer> velocity     = nil;
    id<MTLBuffer> inverseMass_ = nil;
    id<MTLBuffer> renderToParticle_ = nil;
};

class PhysicsWorld {
public:
    explicit PhysicsWorld(id<MTLDevice> device, id<MTLLibrary> library);
    size_t addBody(const MeshData& mesh, const Transform& transform, float inverseMass = 1.0f);
    const PhysicsBody& body(size_t id) const { return bodies_.at(id); }
    // Pass the options used to submit command. Releases frame resources on completion.
    void encodeStep(id<MTL4CommandBuffer> command, float dt, MTL4CommitOptions *completion);
    ~PhysicsWorld();

private:
    id<MTLDevice> device_;
    id<MTLComputePipelineState> integrationPipeline_ = nil;
    std::deque<PhysicsBody> bodies_;
};



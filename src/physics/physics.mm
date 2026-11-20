#include "physics.hpp"
#include "physics/pbd/pbd.hpp"
#include <stdexcept>

PhysicsBody::PhysicsBody(id<MTLDevice> device,const MeshData& mesh, const Transform& transform, float inverseMass) {
    Particle initial;
    const simd_float4x4 model = transform.matrix();
    for (const auto& p : mesh.particlePositions) {
        simd_float4 world = simd_mul(model, simd_float4{p[0], p[1], p[2], 1.0f});
        simd_float3 worldPosition = {world.x, world.y, world.z};
        initial.position.push_back(worldPosition);
        initial.old_position.push_back(worldPosition);
        initial.inverse_mass.push_back(inverseMass);
    }

   const NSUInteger positionBytes =
       initial.position.size() * sizeof(simd_float3);

    positionA_   = [device newBufferWithBytes:initial.position.data() length:positionBytes options:MTLResourceStorageModeShared];
    positionB_   = [device newBufferWithBytes:initial.position.data() length:positionBytes options:MTLResourceStorageModeShared];
    oldPosition_ = [device newBufferWithBytes:initial.old_position.data() length:positionBytes options:MTLResourceStorageModeShared];
    inverseMass_     = [device newBufferWithBytes:initial.inverse_mass.data() length:initial.inverse_mass.size() * sizeof(float) options:MTLResourceStorageModeShared];
    renderToParticle_= [device newBufferWithBytes:mesh.renderToParticle.data()length:mesh.renderToParticle.size() * sizeof(uint32_t)options:MTLResourceStorageModeShared];


}

size_t PhysicsWorld::addBody(const MeshData& mesh,
                             const Transform& transform, float inverseMass) {
    bodies_.emplace_back(device_, mesh, transform, inverseMass);
    return bodies_.size() - 1;
}



PhysicsWorld::PhysicsWorld(id<MTLDevice> device, id<MTLLibrary> library)
:device_(device)
{
    id<MTLFunction> function = [library newFunctionWithName:@"integrateParticles"];


    if (!function)
        throw std::runtime_error("integrateParticles kernel is missing");

   NSError *error = nil;
   integrationPipeline_ = [device newComputePipelineStateWithFunction:function error:&error];

   [function release];
    if (!integrationPipeline_)
        throw std::runtime_error(
            error.localizedDescription.UTF8String
                ?: "Integration pipeline creation failed");
}
void PhysicsWorld::encodeStep(id<MTL4CommandBuffer> command, float dt, MTL4CommitOptions *completion) {
    if (!completion)
        throw std::invalid_argument("Physics encoding requires submission completion options");
    MTL4ArgumentTableDescriptor *tableDescriptor = [MTL4ArgumentTableDescriptor new];
    tableDescriptor.maxBufferBindCount = 5;
    id<MTL4ArgumentTable> table = [device_ newArgumentTableWithDescriptor:tableDescriptor error:nil];
    [tableDescriptor release];
     MTLResidencySetDescriptor *residencyDescriptor = [MTLResidencySetDescriptor new];
    id<MTLResidencySet> residency = [device_ newResidencySetWithDescriptor:residencyDescriptor error:nil];
    [residencyDescriptor release];
    id<MTLBuffer> timestep = [device_ newBufferWithBytes:&dt length:sizeof(dt) options:MTLResourceStorageModeShared];

    if (!table || !residency || !timestep) {
        [table release];
        [residency release];
        [timestep release];
        throw std::runtime_error("Could not create physics frame resources");
    }
    [completion addFeedbackHandler:^(id<MTL4CommitFeedback> feedback) {
        [table release];
        [residency release];
        [timestep release];
    }];
    [residency addAllocation:timestep];
    [table setAddress:timestep.gpuAddress atIndex:4];

    // Add each Physics Body (indicie) for the current position buffer
    for(const PhysicsBody& body : bodies_) {
        [residency addAllocation:body.positionBuffer()];
        [residency addAllocation:body.Old_positionBuffer()];
        [residency addAllocation:body.predictedPositionBuffer()];
        [residency addAllocation:body.InverseMassBuffer()];
    }
    // use Current Reseident Set (PBD set ssubject to change)
    [residency commit];
    [command useResidencySet:residency];
    //Send Buffer and there Posiotions numbers
    id<MTL4ComputeCommandEncoder> encoder = [command computeCommandEncoder];

    // Ensure Encoder isnt faster than render
    [encoder barrierAfterQueueStages:MTLStageDispatch | MTLStageVertex
       beforeStages: MTLStageDispatch
       visibilityOptions:MTL4VisibilityOptionDevice];
    [encoder setComputePipelineState:integrationPipeline_];

    for(PhysicsBody& body : bodies_) {
        [table setAddress:body.positionBuffer().gpuAddress atIndex:0];
        [table setAddress:body.predictedPositionBuffer().gpuAddress atIndex:1];
        [table setAddress:body.Old_positionBuffer().gpuAddress atIndex:2];
        [table setAddress:body.InverseMassBuffer().gpuAddress atIndex:3];

        [encoder setArgumentTable:table];

        NSUInteger count = body.particleCount();
        if(count == 0) continue;
        NSUInteger groupSize = integrationPipeline_.threadExecutionWidth;
        [encoder dispatchThreads:MTLSizeMake(count,1,1)
        threadsPerThreadgroup:MTLSizeMake(groupSize,1,1)];

         body.swapPositionBuffers();

    }

    // ensure render cant finsih before compute
    [encoder barrierAfterStages:MTLStageDispatch
    beforeQueueStages:MTLStageVertex
    visibilityOptions:MTL4VisibilityOptionDevice];
    [encoder endEncoding];






}



PhysicsWorld::~PhysicsWorld() {
    [integrationPipeline_ release];
}

PhysicsBody::~PhysicsBody() {
    [positionA_ release];
    [positionB_ release];
    [oldPosition_ release];
    [inverseMass_ release];
    [renderToParticle_ release];
}

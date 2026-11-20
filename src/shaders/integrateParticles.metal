#include <metal_stdlib>
using namespace metal;

kernel void integrateParticles (
    device const float3* pos [[buffer(0)]],
    device float3* pred_pos [[buffer(1)]],
    device float3* old_pos [[buffer(2)]],
    device const float* inverse_mass[[buffer(3)]],
    constant float& dt [[buffer(4)]],
    uint index[[thread_position_in_grid]]
)
{


    // The host dispatches exactly one thread per particle.
    float3 current_pos = pos[index];
    if (inverse_mass[index] == 0.0f) {
        pred_pos[index] = current_pos;
        old_pos[index] = current_pos;
        return;
    }


    // Gravity is acceleration and does not depend on particle mass.
    float3 gravity{0.0f,0.00f,0.0f};


    float3 acceleration = gravity * inverse_mass[index];

    // v = v + (dt * force_ext * inverse_mass)

  //  float3 temp
    // Verlet prediction assumes a fixed timestep.
    pred_pos[index] = current_pos + (current_pos - old_pos[index])
                    + acceleration * dt * dt;
    old_pos[index] = current_pos;
}

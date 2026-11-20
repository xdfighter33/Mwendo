#ifndef METALPHYSICSENGINE_PBD_HPP
#define METALPHYSICSENGINE_PBD_HPP
#include <vector>
#include <simd/simd.h>
struct Particle {
    std::vector<simd_float3> position;
    std::vector<simd_float3> velocity;
    std::vector<simd_float3> old_position;
    std::vector<float> inverse_mass;
};


struct Particle_pbd {
    std::vector<float> pos_x;
    std::vector<float> pos_y;
    std::vector<float> pos_z;

    std::vector<float> old_pos_x;
    std::vector<float> old_pos_y;
    std::vector<float> old_pos_z;

    std::vector<float> vel_x;
    std::vector<float> vel_y;
    std::vector<float> vel_z;

    std::vector<float> inverse_mass;

};

#endif
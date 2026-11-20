#ifndef METALPHYSICSENGINE_MESH_HPP
#define METALPHYSICSENGINE_MESH_HPP

#include <simd/simd.h>
#include <array>
#include <cstdint>
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

struct Vertex {
    float position[3];
    float normal[3];
};

struct MeshData {
    std::vector<Vertex> vertices;
    std::vector<uint32_t> indices;
    std::vector<std::array<float, 3>> particlePositions;
    std::vector<uint32_t> renderToParticle;
};

// Loads triangle-only OBJ files with position indices (the format of cube.obj).
inline MeshData loadMesh(const std::string &path) {
    std::ifstream file(path);
    if (!file) throw std::runtime_error("Cannot open mesh: " + path);
    MeshData mesh;
    std::string line;
    while (std::getline(file, line)) {
        std::istringstream stream(line);
        std::string tag;
        stream >> tag;
        if (tag == "v") {
            std::array<float, 3> p{};
            if (!(stream >> p[0] >> p[1] >> p[2])) throw std::runtime_error("Invalid mesh vertex");
            mesh.particlePositions.push_back(p);
        } else if (tag == "f") {
            std::array<unsigned, 3> face{};
            std::string extra;
            if (!(stream >> face[0] >> face[1] >> face[2]) || (stream >> extra))
                throw std::runtime_error("Mesh requires triangular faces with position indices");
            for (unsigned i : face)
                if (i == 0 || i > mesh.particlePositions.size()) throw std::runtime_error("Mesh face index out of range");
            const auto &a = mesh.particlePositions[face[0] - 1];
            const auto &b = mesh.particlePositions[face[1] - 1];
            const auto &c = mesh.particlePositions[face[2] - 1];
            simd_float3 ab = {b[0] - a[0], b[1] - a[1], b[2] - a[2]};
            simd_float3 ac = {c[0] - a[0], c[1] - a[1], c[2] - a[2]};
            simd_float3 cross = simd_cross(ab, ac);
            if (simd_length_squared(cross) == 0) throw std::runtime_error("Degenerate mesh triangle");
            simd_float3 n = simd_normalize(cross);
            for (unsigned i : face) {
                const auto &p = mesh.particlePositions[i - 1];
                mesh.vertices.push_back({{p[0], p[1], p[2]}, {n.x, n.y, n.z}});
                mesh.indices.push_back(static_cast<uint32_t>(mesh.indices.size()));
                mesh.renderToParticle.push_back(i - 1);
            }
        }
    }
    if (mesh.indices.empty()) throw std::runtime_error("Mesh has no faces");
    return mesh;
}

#endif

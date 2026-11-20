#ifndef METALPHYSICSENGINE_SCENE_HPP
#define METALPHYSICSENGINE_SCENE_HPP

#include <simd/simd.h>
#include <cmath>
#include <cstdint>
#include <string>
#include <vector>

struct Camera {
    simd_float3 position = {0, 0, 0};
    float verticalFovDegrees = 60.0f;
    float nearPlane = 0.1f;
    float farPlane = 100.0f;

    simd_float4x4 projection(float aspect) const {
        const float radians = verticalFovDegrees * 3.1415926535f / 180.0f;
        const float scale = 1.0f / std::tan(radians * 0.5f);
        simd_float4x4 m;
        m.columns[0] = {scale / aspect, 0, 0, 0};
        m.columns[1] = {0, scale, 0, 0};
        m.columns[2] = {0, 0, farPlane / (nearPlane - farPlane), -1};
        m.columns[3] = {0, 0, nearPlane * farPlane / (nearPlane - farPlane), 0};
        return m;
    }

    simd_float4x4 viewProjection(float aspect) const {
        simd_float4x4 view = matrix_identity_float4x4;
        view.columns[3] = {-position.x, -position.y, -position.z, 1};
        return simd_mul(projection(aspect), view);
    }
};

struct Transform {
    simd_float3 position = {0, 0, 0};
    simd_float3 rotation = {0, 0, 0}; // radians around x, y, z
    simd_float3 scale = {1, 1, 1};

    simd_float4x4 matrix() const {
        const float cx = std::cos(rotation.x), sx = std::sin(rotation.x);
        const float cy = std::cos(rotation.y), sy = std::sin(rotation.y);
        const float cz = std::cos(rotation.z), sz = std::sin(rotation.z);
        simd_float4x4 m;
        m.columns[0] = {scale.x * (cz * cy), scale.x * (sz * cy), scale.x * (-sy), 0};
        m.columns[1] = {scale.y * (cz * sy * sx - sz * cx), scale.y * (sz * sy * sx + cz * cx), scale.y * (cy * sx), 0};
        m.columns[2] = {scale.z * (cz * sy * cx + sz * sx), scale.z * (sz * sy * cx - cz * sx), scale.z * (cy * cx), 0};
        m.columns[3] = {position.x, position.y, position.z, 1};
        return m;
    }
};

struct SceneObject {
    std::string meshFile;
    std::vector<Transform> instances;
    uint32_t material = 0; // 0: cube, 1: grid room
    float inverseMass = 1.0f; // Zero pins all particles in this object.
};

struct Scene {
    Camera camera;
    std::vector<SceneObject> objects;

    static Scene demo() {
        Scene scene;
        Transform cube;
        cube.position = {0, 0, -3};
        cube.rotation = {-0.35f, 0.55f, 0};
        scene.objects.push_back({"cube.obj", {cube}});
        scene.objects.push_back({"room.obj", {Transform{}}, 1, 0.0f});
        return scene;
    }
};

#endif

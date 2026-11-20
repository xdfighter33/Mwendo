#include "cube_shared.metalh"

fragment float4 cubeFragment(CubeVertexOut in [[stage_in]],
                             constant CubeUniforms &uniforms [[buffer(2)]]) {
    float3 normal = normalize(in.normal);
    float3 lightDirection = normalize(float3(-2.5, 4.0, -1.0) - in.worldPosition);
    float3 viewDirection = normalize(uniforms.cameraPosition.xyz - in.worldPosition);
    float3 halfVector = normalize(lightDirection + viewDirection);
    float diffuse = max(dot(normal, lightDirection), 0.0);
    float specular = diffuse > 0.0 ? pow(max(dot(normal, halfVector), 0.0), 32.0) : 0.0;

    float3 baseColor = float3(0.22, 0.53, 0.82);
    if (in.material == 1) {
        // Each visible room plane uses world coordinates for a one-unit grid.
        float2 gridCoordinates = abs(normal.y) > 0.5
            ? in.worldPosition.xz : abs(normal.z) > 0.5
                ? in.worldPosition.xy : in.worldPosition.zy;
        float2 gridDistance = abs(fract(gridCoordinates + 0.5) - 0.5);
        float2 gridWidth = max(fwidth(gridCoordinates), float2(0.001));
        float line = 1.0 - min(min(gridDistance.x / gridWidth.x, gridDistance.y / gridWidth.y), 1.0);
        baseColor = mix(float3(0.48), float3(0.29), line);
        specular *= 0.12;
    }

    float3 color = baseColor * (0.28 + 0.72 * diffuse) + float3(0.8) * (0.35 * specular);
    return float4(color, 1.0);
}

#include "cube_shared.metalh"

vertex CubeVertexOut physicsVertex(
    const device float3 *positions [[buffer(0)]],
    const device uint *renderToParticle [[buffer(1)]],
    constant CubeUniforms &uniforms [[buffer(2)]],
    constant uint &material [[buffer(3)]],
    uint vertexID [[vertex_id]])
{
    uint first = (vertexID / 3) * 3;

    float3 a = positions[renderToParticle[first]];
    float3 b = positions[renderToParticle[first + 1]];
    float3 c = positions[renderToParticle[first + 2]];
    float3 world = positions[renderToParticle[vertexID]];

    CubeVertexOut out;
    out.position = uniforms.viewProjection * float4(world, 1.0);
    out.normal = normalize(cross(b - a, c - a));
    out.worldPosition = world;
    out.material = material;
    return out;
}
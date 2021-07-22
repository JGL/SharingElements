#include "../Types.metal"
#include "Library/Gaussian.metal"

typedef struct {
    float4 color;    //color
    float pointSize; //slider,0,16,8
    float sigma;     //slider
    float power;     //slider
} SpriteUniforms;

typedef struct {
    float4 position [[position]];
    float pointSize [[point_size]];
} CustomVertexData;

vertex CustomVertexData spriteVertex(uint instanceID [[instance_id]],
                                     Vertex in [[stage_in]],
                                     constant VertexUniforms &vertexUniforms [[buffer(VertexBufferVertexUniforms)]],
                                     constant SpriteUniforms &uniforms [[buffer(VertexBufferMaterialUniforms)]],
                                     const device Particle *particles [[buffer(VertexBufferCustom0)]]) {
    Particle particle = particles[instanceID];
    CustomVertexData out;
    out.position = vertexUniforms.modelViewProjectionMatrix * (in.position + float4(particle.position, 0.0));
    out.pointSize = uniforms.pointSize;
    return out;
}

fragment float4 spriteFragment(CustomVertexData in [[stage_in]],
                               const float2 puv [[point_coord]],
                               constant SpriteUniforms &uniforms [[buffer(FragmentBufferMaterialUniforms)]]) {
    const float2 uv = 2.0 * puv - 1.0;
    const float dist = length(uv);
    float result = gaussian(dist, uniforms.sigma, uniforms.power);
    return uniforms.color * float4(1.0, 1.0, 1.0, result);
}

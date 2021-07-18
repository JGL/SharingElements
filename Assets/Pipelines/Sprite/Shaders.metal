#include "../Types.metal"
#include "Library/Shapes.metal"

typedef struct {
    float4 color; //color
    float pointSize; //slider,0,16,8
} SpriteUniforms;

typedef struct {
    float4 position [[position]];
    float pointSize [[point_size]];
} CustomVertexData;

vertex CustomVertexData spriteVertex( uint instanceID [[instance_id]],
                               Vertex in [[stage_in]],
                               constant VertexUniforms &vertexUniforms [[buffer( VertexBufferVertexUniforms )]],
                               constant SpriteUniforms &uniforms [[buffer( VertexBufferMaterialUniforms )]],
                               const device Particle *particles [[buffer( VertexBufferCustom0 )]] )
{
    Particle particle = particles[instanceID];

    float4 position = in.position;
    position.xyz += particle.position;

    CustomVertexData out;
    out.position = vertexUniforms.modelViewProjectionMatrix * position;
    out.pointSize = uniforms.pointSize;
    return out;
}

fragment float4 spriteFragment( CustomVertexData in [[stage_in]],
                               const float2 puv [[point_coord]],
                               constant SpriteUniforms &uniforms [[buffer( FragmentBufferMaterialUniforms )]] )
{
    const float2 uv = 2.0 * puv - 1.0;
    float result = Circle( uv, 1.0 );
    result = smoothstep( 0.1, 0.0 - fwidth( result ), result );
    return uniforms.color * float4( 1.0, 1.0, 1.0, result );
}

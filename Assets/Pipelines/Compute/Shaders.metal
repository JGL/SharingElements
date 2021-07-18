#include "../Types.metal"
#include "Satin/Includes.metal"
#include "Library/Random.metal"

typedef struct {
    int count;
    float time;
    float size; //slider,0,1000,500
} ComputeUniforms;


kernel void resetCompute( uint index [[thread_position_in_grid]],
    device Particle *outBuffer [[buffer( ComputeBufferCustom0 )]],
    const device ComputeUniforms &uniforms [[buffer( ComputeBufferCustom1 )]] )
{
    Particle out;
    const float id = float(index);
    out.position = uniforms.size * float3( 2.0 * random( float2( id, uniforms.time ) ) - 1.0, 2.0 * random( float2( -id, uniforms.time ) ) - 1.0, 0.0 );
    out.velocity = float3( 0.0 );
    outBuffer[index] = out;
}

kernel void updateCompute( uint index [[thread_position_in_grid]],
    device Particle *outBuffer [[buffer( ComputeBufferCustom0 )]],
    const device ComputeUniforms &uniforms [[buffer( ComputeBufferCustom1 )]] )
{
    const float id = float(index);
    Particle in = outBuffer[index];
    Particle out;
    out.position = uniforms.size * float3( 2.0 * random( float2( id, uniforms.time ) ) - 1.0, 2.0 * random( float2( -id, uniforms.time ) ) - 1.0, 0.0 );
    out.velocity = in.velocity;
    outBuffer[index] = out;
}

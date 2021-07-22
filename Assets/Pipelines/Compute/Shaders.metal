#include "../Types.metal"
#include "Satin/Includes.metal"
#include "Library/Random.metal"
#include "Library/Curlnoise.metal"
#include "Damping.metal"
#include "Attraction.metal"

typedef struct {
    int count;
    float time;
    float gridSize;  //slider,0,1000,500
    float curlScale; //slider,0,0.05,0.005
    float homing;    //slider
    float curl;      //slider
    float body;      //slider
    float wind;      //slider
    float spherical; //slider
    float radius;    //slider,0,1000,500
    float damping;   //slider
    float deltaTime;
} ComputeUniforms;

float3 getHomePosition(int id, int halfSquaredCount, float2 gridSize) {
    const int x = id % 512;
    const int y = id / 512;
    const float px = float(x) / 511.0;
    const float py = float(y) / 511.0;
    const float2 pos = gridSize * float2(px, py) - gridSize * 0.5;
    return float3(pos, 0.0);
}

kernel void resetCompute(uint index [[thread_position_in_grid]],
                         device Particle *outBuffer [[buffer(ComputeBufferCustom0)]],
                         const device ComputeUniforms &uniforms [[buffer(ComputeBufferCustom1)]]) {
    Particle out;
    const float id = float(index);
    out.position = getHomePosition(index, 512, uniforms.gridSize);
    out.velocity = 2.0 * float3(random(float2(19 * id, uniforms.time)), random(float2(-120 * id, uniforms.time)), random(float2(-id, 0.2 * uniforms.time))) - 1.0;
    outBuffer[index] = out;
}

kernel void updateCompute(uint index [[thread_position_in_grid]],
                          device Particle *outBuffer [[buffer(ComputeBufferCustom0)]],
                          const device ComputeUniforms &uniforms [[buffer(ComputeBufferCustom1)]]) {
    const float dt = uniforms.deltaTime;
    Particle in = outBuffer[index];
    Particle out;

    const float3 home = getHomePosition(index, 512, uniforms.gridSize);
    float3 pos = in.position;
    float3 vel = in.velocity;

    float3 acc = uniforms.curl * curlNoise(0.1 * pos * uniforms.curlScale + index * 0.05);
    acc += 0.01 * uniforms.homing * attractionForce(pos, home);
    acc += 0.01 * uniforms.spherical * sphericalForce(pos, 0.0, uniforms.radius);
    acc += dampingForce(vel, uniforms.damping);
    vel += acc;

    out.position = pos + vel;

    out.velocity = vel;
    outBuffer[index] = out;
}

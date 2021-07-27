#include "../Types.metal"
#include "Satin/Includes.metal"
#include "Library/Random.metal"
#include "Library/Colors.metal"
#include "Library/Shapes.metal"
#include "Library/Csg.metal"
#include "Library/Curlnoise.metal"
#include "Damping.metal"
#include "Attraction.metal"

typedef struct {
    int count;
    float time;
    float pointSize; //slider,0,32,16
    float gridSize;  //slider,0,1000,500
    float curlScale; //slider,0,0.05,0.005
    float curlSpeed; //slider
    float curl;      //slider
    float homing;    //slider
    float body;      //slider
    float wind;      //slider
    float spherical; //slider
    float radius;    //slider,0,1000,500
    float damping;   //slider
    float deltaTime;
    int points;
    int lines;
} ComputeUniforms;

float3 getHomePosition(int id, int halfSquaredCount, float2 gridSize) {
    const float count = halfSquaredCount;
    const int x = id % halfSquaredCount;
    const int y = id / halfSquaredCount;
    const float px = float(x) / (count - 1.0);
    const float py = float(y) / (count - 1.0);
    const float2 pos = gridSize * float2(px, py) - gridSize * 0.5;
    return float3(pos, 0.0);
}

float2 getUV(int id, int halfSquaredCount) {
    const int x = id % halfSquaredCount;
    const int y = id / halfSquaredCount;
    return float2(x, y) / float(halfSquaredCount);
}

kernel void resetCompute(uint index [[thread_position_in_grid]],
                         device Particle *outBuffer [[buffer(ComputeBufferCustom0)]],
                         constant ComputeUniforms &uniforms [[buffer(ComputeBufferCustom1)]],
                         constant float3 *lines [[buffer(ComputeBufferCustom2)]],
                         constant Colors &colors [[buffer(ComputeBufferCustom3)]],
                         constant Masses &masses [[buffer(ComputeBufferCustom4)]]) {

    const float pointSize = uniforms.pointSize;
    const float fcount = float(uniforms.count);
    const int halfCount = int(sqrt(fcount));
    const float fid = float(index) / fcount;

    const float4 elementColors[11] = {
        colors.oxygen,
        colors.carbon,
        colors.hydrogen,
        colors.nitrogen,
        colors.calcium,
        colors.phosphorus,
        colors.potassium,
        colors.sulfur,
        colors.sodium,
        colors.chlorine,
        colors.magnesium
    };

    const float elementMasses[11] = {
        masses.oxygenMass,
        masses.carbonMass,
        masses.hydrogenMass,
        masses.nitrogenMass,
        masses.calciumMass,
        masses.phosphorusMass,
        masses.potassiumMass,
        masses.sulfurMass,
        masses.sodiumMass,
        masses.chlorineMass,
        masses.magnesiumMass
    };

    float sum = 0.0;
    float mass = 0.0;
    int elementIndex = 0;
    float4 color = float4(0.0);
    for (int i = 0; i < 11; i++) {
        float elementMass = elementMasses[i];
        if (sum > fid) {
            break;
        } else {
            elementIndex = i;
            color = elementColors[i];
            mass = elementMass;
            sum += elementMass;
        }
    }
    Particle out;
    out.position = float4(getHomePosition(index, halfCount, uniforms.gridSize), pointSize);
    out.velocity = float4(0.0, 0.0, 0.0, mass);
    out.color = color;
    out.elementIndex = elementIndex;
    outBuffer[index] = out;
}

float form(float3 pos, constant float3 *lines, int count) {
    float sdf = 100000.0;
    for (int i = 0; i < count; i++) {
        const int lineIndex = i * 2;
        sdf = unionSoft(sdf, Line(pos, lines[lineIndex], lines[lineIndex + 1]) - 5.0, 2.0);
    }
    return sdf;
}

kernel void updateCompute(uint index [[thread_position_in_grid]],
                          device Particle *outBuffer [[buffer(ComputeBufferCustom0)]],
                          constant ComputeUniforms &uniforms [[buffer(ComputeBufferCustom1)]],
                          constant float3 *lines [[buffer(ComputeBufferCustom2)]],
                          constant Colors &colors [[buffer(ComputeBufferCustom3)]],
                          constant Masses &masses [[buffer(ComputeBufferCustom4)]]) {

    const float id = float(index);
    const float time = uniforms.time;
    const float curlSpeed = uniforms.curlSpeed;
    const float pointSize = uniforms.pointSize;
    const int lineCount = uniforms.lines;
    const int halfCount = int(sqrt(float(uniforms.count)));
    const float3 home = getHomePosition(index, halfCount, uniforms.gridSize);

    const float4 elementColors[11] = {
        colors.oxygen,
        colors.carbon,
        colors.hydrogen,
        colors.nitrogen,
        colors.calcium,
        colors.phosphorus,
        colors.potassium,
        colors.sulfur,
        colors.sodium,
        colors.chlorine,
        colors.magnesium
    };

    const float elementMasses[11] = {
        masses.oxygenMass,
        masses.carbonMass,
        masses.hydrogenMass,
        masses.nitrogenMass,
        masses.calciumMass,
        masses.phosphorusMass,
        masses.potassiumMass,
        masses.sulfurMass,
        masses.sodiumMass,
        masses.chlorineMass,
        masses.magnesiumMass
    };

    Particle in = outBuffer[index];

    const int elementIndex = in.elementIndex;
    const float mass = elementMasses[elementIndex];

    float3 pos = in.position.xyz;
    float3 vel = in.velocity.xyz;

    float3 acc = uniforms.curl * curlNoise(pos * uniforms.curlScale + curlSpeed * time + id * (uniforms.spherical + uniforms.body));
    acc += 0.01 * uniforms.homing * attractionForce(pos, home);
    acc += 0.01 * uniforms.spherical * sphericalForce(pos, 0.0, uniforms.radius);

    if (lineCount > 0) {
        const float dist = form(pos, lines, lineCount);
        const float3 esp = float3(0.001, 0.0, 0.0);
        float3 delta = float3(
            dist - form(pos + esp.xyy, lines, lineCount),
            dist - form(pos + esp.yxy, lines, lineCount),
            dist - form(pos + esp.yyx, lines, lineCount));
        delta = normalize(delta);
        acc += 0.01 * uniforms.body * delta * dist;
    }

    acc += dampingForce(vel, uniforms.damping);
    vel += acc;

    Particle out;
    out.position = float4(pos + vel, pointSize);
    out.velocity = float4(vel, mass);
    out.color = elementColors[elementIndex];
    outBuffer[index] = out;
}

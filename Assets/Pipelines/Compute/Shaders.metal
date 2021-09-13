#include "../Types.metal"
#include "Satin/Includes.metal"
#include "Library/Random.metal"
#include "Library/Map.metal"
#include "Library/Colors.metal"
#include "Library/Shapes.metal"
#include "Library/Csg.metal"
#include "Library/Curlnoise.metal"
#include "Library/Repeat.metal"
#include "Damping.metal"
#include "Attraction.metal"

typedef struct {
    int count;
    float time;
    float pointSize; //slider,0,32,16
    float2 gridSize;
    float curlScale; //slider,0,0.05,0.005
    float curlSpeed; //slider
    float curl;      //slider
    float body;      //slider
    float stream;    //slider
    float damping;   //slider
    float dt;        //slider,0,1,1
    float dwellTime; //input,10
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
    const float fid = float(index) / fcount;
    const float time = uniforms.time;

    const float4 elementColors[21] = {
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
        colors.magnesium,
        colors.iron,
        colors.fluorine,
        colors.zinc,
        colors.silicon,
        colors.gallium,
        colors.rubidium,
        colors.strontium,
        colors.bromine,
        colors.lead,
        colors.copper,
    };

    const float elementMasses[21] = {
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
        masses.magnesiumMass,
        masses.ironMass,
        masses.fluorineMass,
        masses.zincMass,
        masses.siliconMass,
        masses.galliumMass,
        masses.rubidiumMass,
        masses.strontiumMass,
        masses.bromineMass,
        masses.leadMass,
        masses.copperMass
    };

    float sum = 0.0;
    float mass = 0.0;
    int elementIndex = 0;
    float4 color = float4(0.0);
    for (int i = 0; i < 21; i++) {
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
    const float px = 0.5 * uniforms.gridSize.x * (2.0 * random(float2(-fid, 2.34 * fid)) - 1.0);
    const float py = 0.5 * uniforms.gridSize.y * (2.0 * random(float2(324.0 * fid, -1.34 * fid)) - 1.0);
    out.position = float4(
        px,
        py,
        0.0,
        pointSize);
    out.velocity = float4(0.0, 0.0, 0.0, mass);
    out.color = color;
    out.life = uniforms.dwellTime * random(float2(fid, time));
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
    const float dt = uniforms.dt;
    const float curlSpeed = uniforms.curlSpeed;
    const float pointSize = uniforms.pointSize;
    const float2 gridSize = uniforms.gridSize;
    const float2 gridSizeHalf = gridSize * 0.5;
    const int lineCount = uniforms.lines;

    const float4 elementColors[21] = {
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
        colors.magnesium,
        colors.iron,
        colors.fluorine,
        colors.zinc,
        colors.silicon,
        colors.gallium,
        colors.rubidium,
        colors.strontium,
        colors.bromine,
        colors.lead,
        colors.copper,
    };

    const float elementMasses[21] = {
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
        masses.magnesiumMass,
        masses.ironMass,
        masses.fluorineMass,
        masses.zincMass,
        masses.siliconMass,
        masses.galliumMass,
        masses.rubidiumMass,
        masses.strontiumMass,
        masses.bromineMass,
        masses.leadMass,
        masses.copperMass
    };

    Particle in = outBuffer[index];

    const int elementIndex = in.elementIndex;
    const float mass = elementMasses[elementIndex];

    float life = in.life;
    float3 pos = in.position.xyz;
    float3 vel = in.velocity.xyz;

    const float dwellTime = uniforms.dwellTime;
    const float lifeTime = life / dwellTime;
    const int low = int(floor(lifeTime));
    const int high = int(ceil(lifeTime));
    const float norm = map(life, low * dwellTime, high * dwellTime, 0.0, 1.0);
    const int state = int(lifeTime) % 2 == 0 ? 0 : 1;
    float3 acc = uniforms.curl * curlNoise(pos * uniforms.curlScale + curlSpeed * time + id * mix(0.0, uniforms.body, state));

    if (state && lineCount > 0) {
        const float dist = form(pos, lines, lineCount);
        const float3 esp = float3(0.001, 0.0, 0.0);
        float3 delta = float3(
            dist - form(pos + esp.xyy, lines, lineCount),
            dist - form(pos + esp.yxy, lines, lineCount),
            dist - form(pos + esp.yyx, lines, lineCount));
        delta = normalize(delta);
        if (!isnan(delta.x) && !isnan(delta.x) && !isnan(delta.x) && !isnan(dist)) {
            acc += norm * 0.01 * uniforms.body * delta * dist;
        }
    } else {
        acc += float3(uniforms.stream, 0.0, 0.0);
    }

    acc += dampingForce(vel, uniforms.damping);
    vel += acc * dt;
    pos += vel * dt;

    if (pos.x > gridSizeHalf.x) {
        pos.x = -gridSizeHalf.x;
    }

    if (pos.y > gridSizeHalf.y) {
        pos.y = -gridSizeHalf.y;
        vel = 0.0;
    } else if (pos.y < -gridSizeHalf.y) {
        pos.y = gridSizeHalf.y;
        vel = 0.0;
    }

    Particle out;
    out.position = float4(pos, pointSize);
    out.velocity = float4(vel, mass);

    // float4 color = elementColors[elementIndex];
    // float alpha = 1.0 - clamp(abs(gmod(time, 20) - float(elementIndex)), 0.0, 1.0);
    // color.a *= alpha;
    out.color = elementColors[elementIndex];
    out.life = life + uniforms.deltaTime;
    outBuffer[index] = out;
}

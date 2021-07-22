#include "Library/Shapes.metal"
#include "Library/Pi.metal"
#include "Library/Csg.metal"

#define MAX_STEPS 64
#define MIN_DIST 0.0
#define MAX_DIST 5000.0
#define SURF_DIST 0.001
#define EPSILON 0.001

typedef struct {
    float4 color; // color
    float4 resolution;
    float3 cameraPosition;
    float3 cameraRight;
    float3 cameraUp;
    float3 cameraForward;
    float2 nearFar;
    float2 cameraDepth;
    float lineWidth; // slider,0,20,5
} LineUniforms;

typedef struct {
    float4 position [[position]];
    float4 startPosition [[flat]];
    float4 endPosition [[flat]];
    float lineWidth [[flat]];
} CustomVertexData;

float scene(float3 p, float3 sp, float3 ep, float lw) {
    return Line(p, sp, ep) - lw;
}

float3 getNormal(float3 p, float3 sp, float3 ep, float lw) {
    const float d = scene(p, sp, ep, lw);
    const float3 e = float3(EPSILON, 0.0, 0.0);
    const float3 gradient = d - float3(scene(p - e.xyy, sp, ep, lw), scene(p - e.yxy, sp, ep, lw), scene(p - e.yyx, sp, ep, lw));
    return normalize(gradient);
}

float render(float3 ro, float3 rd, float3 sp, float3 ep, float lw) {
    float d = 0.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        const float3 p = ro + rd * d;
        const float dist = scene(p, sp, ep, lw);
        d += dist;
        if (dist > MAX_DIST || abs(dist) < SURF_DIST) {
            break;
        }
    }
    return d;
}

vertex CustomVertexData lineVertex(
    uint id [[instance_id]],
    Vertex in [[stage_in]],
    constant VertexUniforms &vertexUniforms [[buffer(VertexBufferVertexUniforms)]],
    constant LineUniforms &uniforms [[buffer(VertexBufferMaterialUniforms)]],
    constant float3 *points [[buffer(VertexBufferCustom0)]]) {
    CustomVertexData out;

    const int index = (int)id;
    const float2 uv = in.uv.xy;
    const float aspect = uniforms.resolution.z;

    const float4x4 mvp = vertexUniforms.modelViewProjectionMatrix;

    const float4 _p0 = float4(points[index], 1.0);
    const float4 _p1 = float4(points[index + 1], 1.0);

    const float4 p0 = mvp * _p0;
    const float4 p1 = mvp * _p1;

    float4 position = mix(p0, p1, uv.x);

    const float2 p0Screen = p0.xy;
    const float2 p1Screen = p1.xy;

    float2 dir = normalize(p1Screen - p0Screen);
    dir.y /= aspect;
    const float2 dirInv = float2(-dir.y, dir.x);

    const float height = uniforms.lineWidth;

    float4 offset = float4(height * mix(dirInv, -dirInv, uv.y), 0.0, 0.0);
    offset += float4(height * mix(-dir, dir, uv.x) + height * mix(dirInv, -dirInv, uv.y), 0.0, 0.0);

    out.position = position + offset;
    out.startPosition = vertexUniforms.modelMatrix * _p0;
    out.endPosition = vertexUniforms.modelMatrix * _p1;
    out.lineWidth = height;
    return out;
}

struct FragOut {
    float4 color [[color(0)]];
    float depth [[depth(any)]];
};

fragment FragOut lineFragment(CustomVertexData in [[stage_in]],
                              constant LineUniforms &uniforms [[buffer(FragmentBufferMaterialUniforms)]],
                              constant float4x4 *view [[buffer(FragmentBufferCustom0)]]) {
    const float2 cameraDepth = uniforms.cameraDepth;
    const float a = cameraDepth.x;
    const float b = cameraDepth.y;

    const float lw = in.lineWidth * 0.25;
    const float4 color = uniforms.color;
    float2 uv = 2.0 * (in.position.xy / uniforms.resolution.xy) - 1.0;
    uv.y *= -1.0;

    const float3 ro = uniforms.cameraPosition;
    const float3 rd = normalize(uv.x * uniforms.cameraRight + uv.y * uniforms.cameraUp + uniforms.cameraForward);

    const float3 startPosition = in.startPosition.xyz;
    const float3 endPosition = in.endPosition.xyz;

    const float d = render(ro, rd, startPosition, endPosition, lw);
    const float3 p = ro + rd * d;

    if (d >= MAX_DIST) {
        discard_fragment();
    }

    FragOut out;

    constant float4x4 &viewMatrix = (*view);
    const float4 ep = viewMatrix * float4(p, 1.0);
    out.depth = 1.0 - (a + b / ep.z);
    out.color = color;
    return out;
}

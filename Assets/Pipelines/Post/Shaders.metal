typedef struct {
    float2 resolution;
    float time;
} PostUniforms;

fragment float4 postFragment(VertexData in [[stage_in]],
                             constant PostUniforms &uniforms [[buffer(FragmentBufferMaterialUniforms)]],
                             texture2d<float, access::sample> renderTex [[texture(FragmentTextureCustom0)]]) {
    constexpr sampler s = sampler(min_filter::linear, mag_filter::linear);
    const float4 sample = renderTex.sample(s, in.uv);
    return sample;
}

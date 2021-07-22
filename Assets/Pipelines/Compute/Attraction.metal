float3 attractionForce(float3 pos, float3 center) {
    return center - pos;
}

float3 sphericalForce(float3 pos, float3 center, float radius) {
    float3 pointOnSphere = radius * normalize(pos);
    return attractionForce(pos, pointOnSphere);
}

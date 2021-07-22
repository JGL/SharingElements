float3 dampingForce(float3 velocity, float damping) {
    return -damping * velocity;
}

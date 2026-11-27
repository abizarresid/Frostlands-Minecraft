// Gentle wind for grass, flowers and leaves.
// worldPos = absolute world position, isTop = vertex is at the top of the texture
vec3 getWaveOffset(vec3 worldPos, int id, bool isTop) {
    float t = frameTimeCounter;
    float strength = 1.0 + rainStrength * 1.2;

    vec2 wind = vec2(
        sin(t * 1.7 + worldPos.x * 0.55 + worldPos.z * 0.25) + sin(t * 2.9 + worldPos.z * 0.9) * 0.35,
        sin(t * 1.3 + worldPos.z * 0.60 - worldPos.x * 0.20) + sin(t * 3.3 + worldPos.x * 0.8) * 0.35
    );

    if (id == ID_PLANT) {
        // single-block plants: only the top moves
        if (isTop) return vec3(wind.x, 0.0, wind.y) * 0.055 * strength;
    } else if (id == ID_PLANT_TOP) {
        // upper half of tall plants: bottom matches the lower half, top moves more
        float amount = isTop ? 0.11 : 0.055;
        return vec3(wind.x, 0.0, wind.y) * amount * strength;
    } else if (id == ID_LEAVES) {
        float rustle = sin(t * 2.3 + worldPos.x * 1.7 + worldPos.y * 1.3 + worldPos.z * 1.1);
        return vec3(wind.x, rustle * 0.6, wind.y) * 0.025 * strength;
    }
    return vec3(0.0);
}

// Water surface shape and underwater light patterns.

// Value noise with a smoother (quintic) curve, so the surface has no grid pattern
float smoothNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Irregular ripples: several layers of noise, each rotated and drifting at its own speed
float waterHeight(vec2 p) {
    float t = frameTimeCounter;
    const mat2 rot = mat2(0.80, -0.60, 0.60, 0.80);
    vec2 wind = vec2(0.55, 0.22);

    float h = 0.0;
    float amp = 0.5;
    float freq = 0.32;
    vec2 q = p;
    for (int i = 0; i < 5; i++) {
        h += smoothNoise(q * freq + wind * t * (0.35 + 0.22 * float(i))) * amp;
        q = rot * q + vec2(13.7, 7.1);
        freq *= 1.95;
        amp *= 0.5;
    }
    return h;
}

// World-space normal of the water's top surface at p (world xz)
vec3 getWaterNormal(vec2 p, float dist) {
    const float e = 0.04;
    float h0 = waterHeight(p);
    float dx = (waterHeight(p + vec2(e, 0.0)) - h0) / e;
    float dz = (waterHeight(p + vec2(0.0, e)) - h0) / e;
    // calm the waves in the distance to avoid shimmering
    float s = 0.38 * WATER_WAVE_STRENGTH * (1.0 + rainStrength * 0.8) / (1.0 + dist * 0.02);
    return normalize(vec3(-dx * s, 1.0, -dz * s));
}

// Bright rippling lines that sunlight makes on the bottom of shallow water
float getCaustics(vec2 p) {
    float t = frameTimeCounter * 0.6;
    float c = 0.0;
    vec2 q = p * 1.1;
    for (int i = 0; i < 3; i++) {
        vec2 w = q + vec2(valueNoise(q * 0.9 + t), valueNoise(q * 0.9 - t + 3.7)) * 1.6;
        float n = valueNoise(w * 1.7);
        c += pow(1.0 - abs(n * 2.0 - 1.0), 8.0);
        q = q * 1.7 + 11.3;
        t *= 1.2;
    }
    return c / 3.0;
}

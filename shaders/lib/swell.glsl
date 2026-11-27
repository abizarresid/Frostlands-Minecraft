// Ocean swell: long rolling waves that move the water surface itself, not just its shading.
// Used by gbuffers_water in both stages (the vertex stage moves the surface, the fragment stage tilts the normal to match).
// The surface only ever dips below its normal height, so it never pokes up through the shore or into boats.
// Storms make it bigger. Lakes and rivers above sea level get a much smaller swell.

// Height of the swell at world position p (xz, in blocks), 0..1, and its slope per block in grad.
float swellWave(vec2 p, float t, out vec2 grad) {
    // direction (x, z), wavelength in blocks, weight
    const vec4 W0 = vec4( 0.92,  0.39, 26.0, 1.00);
    const vec4 W1 = vec4( 0.70, -0.71, 17.0, 0.60);
    const vec4 W2 = vec4( 0.99,  0.12, 11.0, 0.38);
    const vec4 W3 = vec4(-0.31,  0.95,  7.0, 0.22);
    vec4 waves[4] = vec4[4](W0, W1, W2, W3);
    float h = 0.0, total = 0.0;
    grad = vec2(0.0);
    for (int i = 0; i < 4; i++) {
        vec2 d = normalize(waves[i].xy);
        float L = waves[i].z, w = waves[i].w;
        float k = 6.2831853 / L;
        float c = 0.9 * sqrt(L);                      // longer waves travel faster, like real deep-water waves
        float ph = k * (dot(d, p) - c * t);
        h += w * (0.5 + 0.5 * sin(ph));
        grad += w * 0.5 * cos(ph) * k * d;
        total += w;
    }
    grad /= total;
    return h / total;
}

// How deep the swell dips (in blocks) for water whose surface is at height worldY.
float swellAmount(float worldY) {
    float a = WATER_SWELL_HEIGHT * (1.0 + 1.3 * rainStrength);
    float sea = 1.0 - smoothstep(1.5, 3.0, abs(worldY - 62.9));   // the ocean sits at sea level (y 63)
    return a * mix(0.2, 1.0, sea);
}

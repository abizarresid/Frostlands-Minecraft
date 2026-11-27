// Soft shadows. shadowtex1 holds only opaque blocks, so water and glass
// don't darken what's underneath them.
uniform sampler2DShadow shadowtex1;

const vec2 shadowOffsets[8] = vec2[8](
    vec2(-0.7071,  0.7071), vec2(0.0, -0.8750), vec2(0.5303, 0.5303), vec2(-0.625, 0.0),
    vec2( 0.3536, -0.3536), vec2(0.0,  0.3750), vec2(-0.1768, -0.1768), vec2(0.125, 0.0)
);

// Returns 1 = fully lit, 0 = fully shadowed
float getShadow(vec3 playerPos, vec3 worldNormal, float noise) {
#ifndef SHADOWS
    return 1.0;   // shadows off: the shadow pass doesn't even run (shaders.properties)
#endif
    float dist = length(playerPos);
    if (dist > shadowDistance) return 1.0;

    // push the sample point off the surface to avoid "shadow acne"
    vec4 clip = shadowProjection * (shadowModelView * vec4(playerPos, 1.0));
    float distortFactor = length(clip.xy) * 0.88 + 0.12;
    vec3 offsetPos = playerPos + worldNormal * (0.02 + 0.10 * distortFactor) * (2048.0 / float(shadowMapResolution));

    vec3 sp = (shadowProjection * (shadowModelView * vec4(offsetPos, 1.0))).xyz;
    sp = distortShadow(sp) * 0.5 + 0.5;
    sp.z -= 0.00005;

    if (any(lessThan(sp.xy, vec2(0.0))) || any(greaterThan(sp.xy, vec2(1.0)))) return 1.0;

    // rotate the sample pattern per pixel so the blur looks smooth
    float a = noise * 6.2831853;
    mat2 rot = mat2(cos(a), -sin(a), sin(a), cos(a));
    float radius = 1.6 * SHADOW_SOFTNESS / float(shadowMapResolution) / distortFactor * 0.6;

    float lit = 0.0;
#if SHADOW_SAMPLES == 1
    lit = texture(shadowtex1, sp);
#else
    for (int i = 0; i < SHADOW_SAMPLES; i++) {
        lit += texture(shadowtex1, vec3(sp.xy + rot * shadowOffsets[i] * radius, sp.z));
    }
    lit /= float(SHADOW_SAMPLES);
#endif

    // fade shadows out near the edge of the shadow distance
    float fade = smoothstep(shadowDistance * 0.85, shadowDistance, dist);
    return mix(lit, 1.0, fade);
}

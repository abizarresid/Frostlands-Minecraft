// Needs: sky.glsl, and shadows.glsl unless NO_SHADOWS is defined

vec3 getTorchLight(float blockLight) {
    float b = pow(blockLight, 3.0) * 1.5 + pow(blockLight, 8.0) * 1.6;
    return TORCH_COLOR * b * TORCH_BRIGHTNESS;
}

// albedo: linear colour. lm: (block light, sky light) in 0..1
vec3 computeLighting(vec3 albedo, vec3 playerPos, vec3 worldNormal, vec3 viewNormal, vec2 lm, int id, bool hasNormal) {
    vec3 lightDir = normalize(shadowLightPosition);
    float skyLight = lm.y;

    bool foliage = id == ID_PLANT || id == ID_PLANT_TOP || id == ID_LEAVES;

    float NdotL = hasNormal ? dot(viewNormal, lightDir) : 0.6;
    float diffuse;
    if (foliage) {
        // leaves and grass let some light through
        diffuse = 0.45 + 0.4 * max(NdotL, 0.0);
    } else {
        diffuse = max(NdotL, 0.0);
    }

    vec3 direct = vec3(0.0);
#if !defined NETHER && !defined END
    if (diffuse > 0.001) {
        float shadow = 1.0;
    #ifndef NO_SHADOWS
        vec3 biasNormal = foliage ? mat3(gbufferModelViewInverse) * lightDir : worldNormal;
        shadow = getShadow(playerPos, biasNormal, ign(gl_FragCoord.xy));
    #endif
        // stop sunlight leaking into caves beyond the shadow map
        shadow *= smoothstep(0.02, 0.25, skyLight);
        direct = getDirectLightColor() * diffuse * shadow;
    }
#endif

    vec3 ambient = getAmbientColor();
#if defined NETHER || defined END
    vec3 skyAmbient = ambient;
#else
    float upFacing = hasNormal ? worldNormal.y * 0.5 + 0.5 : 0.75;
    vec3 skyAmbient = ambient * (skyLight * skyLight) * (0.65 + 0.35 * upFacing);
#endif

    vec3 torch = getTorchLight(lm.x);
    vec3 minLight = vec3(0.005, 0.006, 0.008) + nightVision * vec3(0.25);

    vec3 lit = albedo * (direct + skyAmbient + torch + minLight);

    if (id == ID_EMISSIVE) {
        // torches, lanterns, glowstone... glow a little on their own
        lit += albedo * smoothstep(0.35, 0.9, luminance(albedo) * 2.0) * 3.0;
    }
    return lit;
}

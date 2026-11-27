// Water (refraction, depth colour, caustics, reflections, sun glint),
// underwater fog and atmospheric haze.
/*
const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA16;
const bool colortex1Clear = true;
const vec4 colortex1ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const int colortex2Format = RG8;
const bool colortex2Clear = true;
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/
#include "/lib/settings.glsl"
// Per-style fog/mist/cloud scales (Classic = all identity)
#if LOOK_STYLE == 0
    #define LOOK_HAZE_MUL      1.0
    #define LOOK_HAZE_START    40.0
    #define LOOK_HAZE_TINT     vec3(1.0)
    #define LOOK_FOG_DESAT     0.0
    #define LOOK_MIST_MUL      1.0
    #define LOOK_MIST_TINT     vec3(1.0)
    #define LOOK_CLOUD_MUL     1.0
    #define LOOK_CLOUD_Y_LOW   125.0
    #define LOOK_CLOUD_Y_HIGH  200.0
    #define LOOK_FOREST_FOG    0.0
#elif LOOK_STYLE == 1
    // PNW Moody: clear near-field (0-56m), layered blue-slate ridge perspective,
    // patchy drifting mid-slope clouds (Y 95-170), and low Puget Sound marine layer
    #define LOOK_HAZE_MUL      1.15
    #define LOOK_HAZE_START    56.0
    #define LOOK_HAZE_TINT     vec3(0.86, 0.92, 1.00)
    #define LOOK_FOG_DESAT     0.24
    #define LOOK_MIST_MUL      1.20
    #define LOOK_MIST_TINT     vec3(0.92, 0.96, 1.02)
    #define LOOK_CLOUD_MUL     ((MOUNTAIN_CLOUDS < 0.0) ? 1.35 : MOUNTAIN_CLOUDS)
    #define LOOK_CLOUD_Y_LOW   95.0
    #define LOOK_CLOUD_Y_HIGH  170.0
    #define LOOK_FOREST_FOG    (((FOREST_FOG < 0.0) ? 0.55 : FOREST_FOG) * 0.42)
#elif LOOK_STYLE == 2
    // Clear Winter: long crisp visibility, light icy-blue haze, minimal mist & high clouds
    #define LOOK_HAZE_MUL      0.45
    #define LOOK_HAZE_START    75.0
    #define LOOK_HAZE_TINT     vec3(0.95, 0.99, 1.06)
    #define LOOK_FOG_DESAT     0.10
    #define LOOK_MIST_MUL      0.35
    #define LOOK_MIST_TINT     vec3(0.95, 0.98, 1.05)
    #define LOOK_CLOUD_MUL     ((MOUNTAIN_CLOUDS < 0.0) ? 0.40 : MOUNTAIN_CLOUDS)
    #define LOOK_CLOUD_Y_LOW   145.0
    #define LOOK_CLOUD_Y_HIGH  220.0
    #define LOOK_FOREST_FOG    (((FOREST_FOG < 0.0) ? 0.15 : FOREST_FOG) * 0.42)
#else
    // Dreamy (LOOK_STYLE == 3): crisp near-field, milky lavender-pink distance & low-area haze,
    // heavy luminous grey-lavender fog in snowy/overcast weather
    #define LOOK_HAZE_MUL      (0.60 + rainStrength * 1.1)     // crisp days, thick only in snow/rain (was 1.18: a white-out)
    #define LOOK_HAZE_START    96.0
    #define LOOK_HAZE_TINT     vec3(1.03, 0.97, 1.07)
    #define LOOK_FOG_DESAT     0.16
    #define LOOK_MIST_MUL      (0.55 + rainStrength * 0.9)
    #define LOOK_MIST_TINT     vec3(1.02, 0.96, 1.08)
    #define LOOK_CLOUD_MUL     ((MOUNTAIN_CLOUDS < 0.0) ? 0.85 : MOUNTAIN_CLOUDS)
    #define LOOK_CLOUD_Y_LOW   110.0
    #define LOOK_CLOUD_Y_HIGH  190.0
    #define LOOK_FOREST_FOG    (((FOREST_FOG < 0.0) ? 0.50 : FOREST_FOG) * 0.42)
#endif
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

#ifdef VERTEX
out vec2 texcoord;
void main() {
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.xy;
}
#endif

#ifdef FRAGMENT

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;   // r: whitecaps and surf, g: surface seen from below (gbuffers_water)
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform float hearthSettle;      // 1 just after a teleport, fading to 0 (shaders.properties)
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;   // Distant Horizons depth, with water
uniform sampler2D dhDepthTex1;   // ... without water (the sea floor)
uniform mat4 dhProjectionInverse;
uniform int dhRenderDistance;     // Iris provides this as an int (blocks)
#endif

in vec2 texcoord;

#include "/lib/sky.glsl"
#include "/lib/shadows.glsl"
#include "/lib/lighting.glsl"
#include "/lib/water.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

// Screen-space reflection against the opaque depth buffer
bool traceReflection(vec3 start, vec3 dir, float dither, out vec2 hitUV) {
    float stepLen = 0.4 + length(start) * 0.02;
    vec3 pos = start + dir * stepLen * dither;
    vec3 prev = start;

    for (int i = 0; i < 8; i++) {
        if (pos.z > -near) return false;
        vec3 screen = viewToScreen(pos);
        if (screen.x < 0.0 || screen.x > 1.0 || screen.y < 0.0 || screen.y > 1.0 || screen.z > 1.0) return false;

        float sceneDepth = texture(depthtex1, screen.xy).r;
        float sceneZ = screenToView(screen.xy, sceneDepth).z;
        float diff = sceneZ - pos.z; // > 0 means the ray is behind the scene

        if (diff > 0.0 && sceneDepth < 1.0) {
            if (diff < stepLen * 2.5 + 0.5) {
                // refine the hit with a short binary search
                vec3 a = prev, b = pos;
                for (int j = 0; j < 2; j++) {
                    vec3 m = (a + b) * 0.5;
                    vec3 ms = viewToScreen(m);
                    float mz = screenToView(ms.xy, texture(depthtex1, ms.xy).r).z;
                    if (mz - m.z > 0.0) b = m; else a = m;
                }
                hitUV = viewToScreen(b).xy;
                return true;
            }
            return false;
        }
        prev = pos;
        stepLen *= 1.9;
        pos += dir * stepLen;
    }
    return false;
}

// Clouds seen in the water: one noise lookup instead of the sky's two plus self-shadowing.
// Rippled reflections hide the difference, and it runs on every water pixel, so it has to be cheap.
vec4 getReflectedClouds(vec3 viewDir) {
#if !defined NETHER && !defined END && CLOUD_STYLE != 0
    vec3 dir = mat3(gbufferModelViewInverse) * viewDir;
    if (dir.y < 0.015) return vec4(0.0, 0.0, 0.0, 1.0);
    float t = (260.0 - cameraPosition.y) / dir.y;
    if (t < 0.0) return vec4(0.0, 0.0, 0.0, 1.0);
    vec2 p = (cameraPosition.xz + dir.xz * t + vec2(frameTimeCounter * 1.5, frameTimeCounter * 0.5)) * 0.0021;
    float coverage = CLOUD_COVERAGE + rainStrength * 0.35;
    float density = smoothstep(1.0 - coverage, 1.0 - coverage + 0.22, cloudFbm(p));
    if (density <= 0.0) return vec4(0.0, 0.0, 0.0, 1.0);
    vec3 col = getAmbientColor() * 1.25 + getDirectLightColor() * 0.35;
    float a = density * exp(-t * 0.00030) * smoothstep(0.015, 0.09, dir.y);
    return vec4(col * a, 1.0 - a);
#else
    return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

// Water colour by style. Style 3 (Auto) picks by where the water is: the sea and low-lying water are the
// dark forest-lake look; lakes and tarns up in the mountains turn glacial turquoise (rock flour from the ice).
// surfaceY = world height of the water surface.
void waterLook(float surfaceY, out vec3 absorb, out vec3 tint, out float scatterK) {
    vec3 aLake = vec3(0.65, 0.30, 0.26), tLake = vec3(0.004, 0.018, 0.016); float kLake = 0.45;   // dark forest lake
    vec3 aGlac = vec3(0.55, 0.085, 0.065), tGlac = vec3(0.020, 0.200, 0.215); float kGlac = 0.55;  // glacial
    vec3 aClear = vec3(0.40, 0.10, 0.075), tClear = vec3(0.010, 0.050, 0.060); float kClear = 0.30; // clear
#if WATER_STYLE == 3
    float g = smoothstep(GLACIAL_START, GLACIAL_START + 25.0, surfaceY);
    absorb = mix(aLake, aGlac, g); tint = mix(tLake, tGlac, g); scatterK = mix(kLake, kGlac, g);
#elif WATER_STYLE == 2
    absorb = aLake; tint = tLake; scatterK = kLake;
#elif WATER_STYLE == 1
    absorb = aGlac; tint = tGlac; scatterK = kGlac;
#else
    absorb = aClear; tint = tClear; scatterK = kClear;
#endif
    absorb /= WATER_CLARITY;
    scatterK /= WATER_CLARITY;
}

// GGX highlight for the sun on the water
float sunGlint(vec3 n, vec3 V, vec3 L, float roughness) {
    vec3 H = normalize(L - V);
    float NdotH = max(dot(n, H), 0.0);
    float NdotL = max(dot(n, L), 0.0);
    float a2 = roughness * roughness * roughness * roughness;
    float d = NdotH * NdotH * (a2 - 1.0) + 1.0;
    float D = a2 / (3.14159 * d * d);
    float F = 0.02 + 0.98 * pow(1.0 - max(dot(H, -V), 0.0), 5.0);
    return min(D * F * NdotL * 0.25, 6.0);
}

vec3 renderWater(vec3 color, vec4 data, float depth0, vec3 viewPos, vec3 viewDir, float dist, float foam) {
    bool top = data.a > 0.5;
    float skyLight = top ? (data.a - 0.6) / 0.4 : (data.a - 0.15) / 0.3;
    skyLight = clamp(skyLight, 0.0, 1.0);
    float blockLight = data.b;
    vec3 n = decodeNormal(data.rg);
    vec3 wn = mat3(gbufferModelViewInverse) * n;
    vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    float noise = ign(gl_FragCoord.xy);

    vec3 sunCol = getDirectLightColor();
    float surfShadow = 0.0;
#if !defined NETHER && !defined END
    surfShadow = getShadow(playerPos, vec3(0.0, 1.0, 0.0), noise) * smoothstep(0.02, 0.25, skyLight);
#endif

    // --- refraction: look at the bottom through the bent surface
    float depth1 = texture(depthtex1, texcoord).r;
    float rawDepth = depth1 >= 1.0 ? 64.0 : distance(screenToView(texcoord, depth1), viewPos);
    vec2 refrUV = texcoord;
    if (top) {
        // bend the view by the surface normal in screen space, gently (it used to shift up to 6% of the screen)
        vec2 offset = n.xy * vec2(1.0, viewWidth / viewHeight) * 0.025 * clamp(rawDepth * 0.35, 0.0, 1.0) / (1.0 + dist * 0.05);
        vec2 bent = clamp(texcoord + offset, 0.001, 0.999);
        // fade the bend out smoothly where the bent sample isn't underwater (shore, fish, plants, the hand):
        // the old hard on/off switch made things under the water jump back and forth as ripples moved
        float okDepth = smoothstep(0.0, 0.0006, texture(depthtex1, bent).r - depth0);
        float okWater = smoothstep(0.1, 0.3, texture(colortex1, bent).a);
        refrUV = mix(texcoord, bent, okDepth * okWater);
    }
    vec3 refracted = texture(colortex0, refrUV).rgb;
    float floorDepth = texture(depthtex1, refrUV).r;
    vec3 floorView = screenToView(refrUV, floorDepth);
    float waterDepth = floorDepth >= 1.0 ? 64.0 : distance(floorView, viewPos);
    if (!top) waterDepth = min(waterDepth, 1.5);

    // --- caustics: rippling sunlight on the bottom
#ifdef CAUSTICS
    if (top && floorDepth < 1.0 && dist < 40.0) {
        vec3 floorWorld = (gbufferModelViewInverse * vec4(floorView, 1.0)).xyz + cameraPosition;
        float c = getCaustics(floorWorld.xz);
        float strength = surfShadow * exp(-waterDepth * 0.22) * clamp(waterDepth * 1.5, 0.0, 1.0);
        refracted *= 1.0 + c * 3.0 * strength * clamp(luminance(sunCol) / 2.5, 0.0, 1.0);
    }
#endif

    // --- absorption: red fades first, so deep water turns teal then blue
    vec3 absorb, waterTint; float scatterK;
    waterLook(playerPos.y + cameraPosition.y, absorb, waterTint, scatterK);
    float scatterAmount = 1.0 - exp(-waterDepth * scatterK);
    vec3 transmit = exp(-absorb * waterDepth);
    vec3 scatterCol = waterTint *
        (getAmbientColor() * skyLight * skyLight * 2.4 + sunCol * surfShadow * 0.35 + getTorchLight(blockLight) * 0.3 + 0.01);
    vec3 body = refracted * transmit + scatterCol * scatterAmount;

    // --- reflection
    float cosTheta = clamp(dot(-viewDir, n), 0.0, 1.0);
    float fresnel = 0.02 + 0.98 * pow(1.0 - cosTheta, 5.0);
    vec3 R = reflect(viewDir, n);
    // clouds in the reflection only where the reflection actually shows (glancing angles), drawn the cheap way
    vec4 reflClouds = fresnel > 0.05 ? getReflectedClouds(R) : vec4(0.0, 0.0, 0.0, 1.0);
    vec3 reflection = (getSkyColor(R) * reflClouds.a + reflClouds.rgb) * (skyLight * skyLight * 0.95 + 0.05);
#ifdef WATER_REFLECTIONS
    vec2 hitUV;
    // far water and rays pointing up into the sky just reflect the sky (most of the open ocean): skip the trace
    float rUp = (mat3(gbufferModelViewInverse) * R).y;
    if (dist < 48.0 && fresnel > 0.05 && rUp > 0.02 && traceReflection(viewPos, R, noise, hitUV)) {
        // a hit on something under the water surface isn't a reflection: ignore it (those flashed in and out)
        bool underwater = texture(depthtex0, hitUV).r < texture(depthtex1, hitUV).r - 1e-5;
        vec2 edge = smoothstep(0.0, 0.08, hitUV) * smoothstep(1.0, 0.92, hitUV);
        if (!underwater) reflection = mix(reflection, texture(colortex0, hitUV).rgb, edge.x * edge.y * smoothstep(0.02, 0.10, rUp));
    }
#endif

    vec3 result = mix(body, reflection, fresnel);
    result += sunCol * surfShadow * sunGlint(n, viewDir, normalize(shadowLightPosition), 0.16) * (1.0 - foam);
    // whitecaps and breaking surf: white water, lit like snow
    if (top && foam > 0.0) {
        // lit a little below snow, and never fully opaque, so it reads as wet foam rather than painted white
        vec3 foamCol = vec3(0.84, 0.89, 0.92) * (getAmbientColor() * skyLight * 1.05 + sunCol * surfShadow * 0.32 + getTorchLight(blockLight) * 0.3 + 0.01);
        result = mix(result, foamCol, foam * 0.85);
    }
    return result;
}

// The water surface seen from underneath. Looking steeply up you see the world above through a bright
// circle (Snell's window); further out the surface turns into a dark mirror of the water below (total
// internal reflection). With big waves, the window moves and breaks up as they pass over you.
vec3 renderUnderside(vec3 color, vec4 data, vec3 viewDir) {
    vec3 n = decodeNormal(data.rg);                    // points down, toward the viewer
    float cosI = clamp(dot(-viewDir, n), 0.0, 1.0);
    float skyLight = clamp((data.a - 0.6) / 0.4, 0.0, 1.0);
    // bend the view through the surface a little
    vec2 refrUV = clamp(texcoord + n.xy * 0.03, 0.001, 0.999);
    vec3 above = texture(colortex0, refrUV).rgb;
    vec3 deep = vec3(0.012, 0.065, 0.08) * (getAmbientColor() * 2.4 * skyLight + getDirectLightColor() * 0.15 * skyLight + 0.03);
    float window = smoothstep(0.58, 0.74, cosI);       // the critical angle of water is about 48 degrees
    float fresnel = 0.02 + 0.98 * pow(1.0 - cosI, 5.0);
    vec3 through = above * (1.0 - fresnel) * 0.9 + deep * fresnel;
    vec3 result = mix(deep * 1.15, through, window);
    // a faint bright edge where the window ends
    result += getAmbientColor() * skyLight * 0.04 * smoothstep(0.5, 0.66, cosI) * (1.0 - window);
    return result;
}

#ifdef DISTANT_HORIZONS
vec3 dhScreenToView(vec2 uv, float depth) {
    vec4 v = dhProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
    return v.xyz / v.w;
}

// The sea far away, beyond the normal render distance: no waves out there anyway, so a cheap version of
// renderWater: sky and cloud reflection, the dark body of the water, a hint of the sea floor in the shallows.
vec3 renderFarWater(vec3 floorColor, vec3 viewPos, vec3 floorPos, vec3 viewDir) {
    vec3 n = mat3(gbufferModelView) * vec3(0.0, 1.0, 0.0);
    float cosTheta = clamp(dot(-viewDir, n), 0.0, 1.0);
    float fresnel = 0.02 + 0.98 * pow(1.0 - cosTheta, 5.0);
    vec3 R = reflect(viewDir, n);
    float eyeSky = eyeBrightnessSmooth.y / 240.0;
    vec3 reflection = getSkyColor(R) * max(eyeSky, 0.3);
    float waterDepth = distance(viewPos, floorPos);
    vec3 absorb, tint; float scatterK;
    waterLook((gbufferModelViewInverse * vec4(viewPos, 1.0)).y + cameraPosition.y, absorb, tint, scatterK);
    vec3 body = floorColor * exp(-absorb * waterDepth)
              + tint * (getAmbientColor() * 2.4 + getDirectLightColor() * 0.35) * (1.0 - exp(-waterDepth * 0.4));
    return mix(body, reflection, fresnel);
}
#endif

#if !defined NETHER && !defined END
// The colour everything far away fades into: the sky's colour in that direction, greyed into aerial haze
// (warmer toward a low sun). Far land, the edge of the world and the sky at and below the horizon all use it,
// so the sea runs out to the horizon with no seam.
vec3 horizonHaze(vec3 viewDir, float eyeSky) {
    vec3 fogCol = getSkyColor(viewDir);
    float h = getSunHeight();
    float sunset = getSunsetFactor(h);
#if LOOK_STYLE == 1
    float night = getNightFactor(h);
    float dirY = (mat3(gbufferModelViewInverse) * viewDir).y;
    float skyLum = luminance(fogCol);

    // Keep cool slate-blue chromaticity instead of washing to flat grey
    vec3 slateBase = vec3(skyLum) * vec3(0.68, 0.80, 0.96);
    vec3 hazeCol = mix(slateBase, fogCol, 0.38 + 0.50 * sunset);
    hazeCol = mix(hazeCol, vec3(luminance(hazeCol)) * vec3(0.92, 0.96, 1.02), LOOK_FOG_DESAT) * LOOK_HAZE_TINT;

    // Brighter silvery band right along the horizon (dampened at night and in heavy rain)
    float horizonBand = 1.0 - smoothstep(0.0, 0.16, abs(dirY));
    float dayVis = (1.0 - night) * (1.0 - 0.35 * rainStrength);
    hazeCol += vec3(0.88, 0.93, 0.98) * (0.14 * skyLum + 0.035) * horizonBand * dayVis;

    // Heavier, cooler, slightly darker tone during Pacific rain
    hazeCol *= mix(vec3(1.0), vec3(0.76, 0.82, 0.88), rainStrength);
    return mix(vec3(0.003, 0.004, 0.006), max(hazeCol, 0.0), eyeSky);
#elif LOOK_STYLE == 3
    float night = getNightFactor(h);
    float dirY = (mat3(gbufferModelViewInverse) * viewDir).y;
    float skyLum = max(luminance(fogCol), 0.0);
    float pastel = clamp(PASTEL_AMOUNT, 0.0, 1.5);

    // Milky lavender-pink haze in clear/sunset air; fades far trees to pale lavender silhouettes
    vec3 lavenderBase = vec3(skyLum) * mix(vec3(0.90, 0.90, 1.02), vec3(0.98, 0.88, 1.08), clamp(pastel * 0.75, 0.0, 1.0));
    vec3 sunsetTint   = mix(vec3(1.0), vec3(1.06, 0.94, 0.96), sunset * clamp(pastel, 0.0, 1.2));
    vec3 hazeCol      = mix(lavenderBase, fogCol, 0.42 + 0.42 * sunset) * sunsetTint;
    hazeCol = mix(hazeCol, vec3(luminance(hazeCol)) * vec3(0.99, 0.95, 1.05), LOOK_FOG_DESAT) * LOOK_HAZE_TINT;

    // Soft milky horizon veil (gentle, never harsh)
    float horizonBand = 1.0 - smoothstep(0.0, 0.22, abs(dirY));
    float dayVis = (1.0 - night * 0.85) * (1.0 - 0.35 * rainStrength);
    vec3 milkyVeil = mix(vec3(0.94, 0.88, 1.02), vec3(1.04, 0.89, 0.86), sunset);
    hazeCol += milkyVeil * (0.05 * skyLum + 0.015 * clamp(pastel, 0.0, 1.2)) * horizonBand * dayVis;

    // Overcast / snowy weather: heavy soft grey-lavender fog that swallows distant ridges, never black
    float overcastLum = max(skyLum, mix(0.28, 0.045, night));
    vec3 overcastCol  = vec3(overcastLum) * vec3(0.95, 0.93, 1.03);
    hazeCol = mix(hazeCol, overcastCol, rainStrength * 0.88);

    // Pleasant cool purple cave/interior fallback instead of near-black
    vec3 interiorCol = vec3(0.010, 0.009, 0.018);
    return mix(interiorCol, max(hazeCol, 0.0), eyeSky);
#else
    vec3 hazeCol = mix(vec3(luminance(fogCol)) * vec3(0.74, 0.84, 0.96), fogCol, 0.30 + 0.60 * sunset);
    hazeCol = mix(hazeCol, vec3(luminance(hazeCol)) * vec3(0.94, 0.97, 1.01), LOOK_FOG_DESAT) * LOOK_HAZE_TINT;
    return mix(vec3(0.004, 0.005, 0.007), hazeCol, eyeSky);
#endif
}

#if LOOK_STYLE == 1 && !defined NETHER && !defined END
vec3 pnwAtmosphere(vec3 color, vec3 worldPos, vec3 viewDir, float dist, float eyeSky, float h, float sunset) {
    // 3 cheap valueNoise(vec2) lookups total; Y is folded into nWisp for free horizontal layering
    vec2 wind1 = vec2(frameTimeCounter * 0.0045,  frameTimeCounter * 0.0020);
    vec2 wind2 = vec2(-frameTimeCounter * 0.0090, frameTimeCounter * 0.0055);
    float nBank   = valueNoise(worldPos.xz * 0.0040 + wind1);
    float nWisp   = valueNoise(worldPos.xz * 0.0130 + vec2(worldPos.y * 0.032, -worldPos.y * 0.020) + wind2);
    float nMarine = valueNoise(worldPos.xz * 0.0026 + wind1 * 0.65);

    // Smooth diurnal marine-layer curve: peaks at dawn/morning (23000..2000), clears by afternoon
    float tDay = mod(float(worldTime) + 1500.0, 24000.0);
    float morning = smoothstep(0.0, 1800.0, tDay) * (1.0 - smoothstep(2600.0, 6800.0, tDay));

    vec3 farHazeCol = horizonHaze(viewDir, eyeSky);
    float ambLum = luminance(getAmbientColor());
    vec3 dirCol = getDirectLightColor();
    float outdoor = smoothstep(0.05, 0.35, eyeSky);

    // --- 1) Marine layer: low, flat, brighter fog bank far out over open water / low coasts (Y < ~75) ---
    float marineTop = 75.0 + (nMarine - 0.5) * 6.0 + 4.0 * rainStrength;
    float inMarineY = 1.0 - smoothstep(63.5, marineTop, worldPos.y);
    float camLow = 1.0 - smoothstep(66.0, 115.0, cameraPosition.y);
    float marineHeightW = inMarineY * (0.48 + 0.52 * camLow);
    float marineDist = smoothstep(mix(70.0, 28.0, rainStrength), mix(280.0, 110.0, rainStrength), dist);
    float marinePatch = mix(0.65, 1.0, smoothstep(0.22, 0.78, nMarine));
    float marineStrength = (0.16 + 0.52 * morning + 0.42 * rainStrength) * VALLEY_MIST * LOOK_MIST_MUL;
    float marine = clamp(marineDist * marineHeightW * marinePatch * (1.0 - exp(-dist * 0.0045 * marineStrength)), 0.0, 0.86);

    vec3 marineCol = (vec3(ambLum) * vec3(0.86, 0.92, 0.99) * 1.45 + dirCol * 0.07) * LOOK_MIST_TINT;
    marineCol = mix(marineCol, farHazeCol, smoothstep(220.0, 620.0, dist));
    marineCol = mix(vec3(0.003, 0.004, 0.006), max(marineCol, 0.0), eyeSky);

    // --- 2) Patchy mid-slope cloud bands (Y 95-170), high ceiling & valley pockets ---
    float yDrop = 14.0 * rainStrength;
    float yWave = worldPos.y + (nBank - 0.5) * 34.0 + yDrop;
    float bandLow  = smoothstep(LOOK_CLOUD_Y_LOW - 16.0, LOOK_CLOUD_Y_LOW + 20.0, yWave);
    float bandHigh = 1.0 - smoothstep(LOOK_CLOUD_Y_HIGH - 18.0, LOOK_CLOUD_Y_HIGH + 34.0, yWave);
    float slopeBand = bandLow * bandHigh;

    // Peaks above the band either poke through clear gaps or vanish into the overcast ceiling
    float peakCeiling = smoothstep(LOOK_CLOUD_Y_HIGH + 12.0 - yDrop, LOOK_CLOUD_Y_HIGH + 90.0 - yDrop, worldPos.y)
                      * smoothstep(0.28 - 0.18 * rainStrength, 0.76 - 0.12 * rainStrength, nBank);

    // Torn wisps with clear gaps between bands
    float wispField = nBank * 0.62 + nWisp * 0.38;
    float wispPatch = smoothstep(0.42 - 0.14 * rainStrength, 0.80 - 0.10 * rainStrength, wispField);

    // Patchy valley pocket wisps (forested hollows Y 68-105, morning & rain only)
    float valleyY = smoothstep(64.0, 74.0, worldPos.y) * (1.0 - smoothstep(88.0, 110.0, worldPos.y));
    float valleyPatch = smoothstep(0.50 - 0.12 * rainStrength, 0.82, nWisp * 0.60 + nBank * 0.40);
    float valleyWisp = valleyY * valleyPatch * (0.20 + 0.55 * morning + 0.55 * rainStrength) * LOOK_FOREST_FOG;

    // Keep foreground clear unless the player climbs directly into the cloud band
    float camInBand = smoothstep(LOOK_CLOUD_Y_LOW, LOOK_CLOUD_Y_LOW + 25.0, cameraPosition.y)
                    * (1.0 - smoothstep(LOOK_CLOUD_Y_HIGH - 10.0, LOOK_CLOUD_Y_HIGH + 35.0, cameraPosition.y));
    float cloudDist = smoothstep(mix(48.0, 22.0, camInBand), mix(135.0, 65.0, camInBand), dist);

    float cloudDensity = (slopeBand * wispPatch * 0.88 + peakCeiling * 0.65 + valleyWisp * 0.55)
                       * LOOK_CLOUD_MUL * (1.0 + 0.65 * rainStrength);
    float slopeCloud = (1.0 - exp(-dist * 0.0085 * cloudDensity)) * cloudDist * 0.86;

    vec3 cloudCol = vec3(ambLum) * vec3(0.92, 0.96, 1.02) * 1.62 + dirCol * (0.12 + 0.08 * sunset);
    cloudCol *= mix(vec3(1.0), vec3(0.80, 0.85, 0.91), rainStrength);
    cloudCol = mix(cloudCol, farHazeCol, smoothstep(320.0, 760.0, dist) * 0.75);
    cloudCol = mix(vec3(0.003, 0.004, 0.006), max(cloudCol, 0.0), max(eyeSky, 0.45));

    // --- 3) Layered ridge aerial perspective (clear near field, darker blue-slate mid ridges -> pale slate far) ---
    float hazeStart = mix(LOOK_HAZE_START, 24.0, rainStrength);
    float dHaze = max(dist - hazeStart, 0.0);
    float hazeOnset = smoothstep(0.0, 45.0, dHaze);

    // Humid valley air is denser than high ridge crests, separating stacked ridges
    float avgAlt = max(0.5 * (cameraPosition.y + worldPos.y) - 63.0, 0.0);
    float altDensity = 0.55 + 0.45 * exp(-avgAlt * 0.011);

    float baseDensity = (0.0026 + 0.0018 * sunset + 0.0052 * rainStrength) * FOG_DENSITY * LOOK_HAZE_MUL;
    float haze = (1.0 - exp(-dHaze * baseDensity * altDensity)) * hazeOnset;

    // Two-stage colour: darker steel-blue on mid ridges so forests stay dark silhouettes,
    // stepping lighter toward pale silvery-slate on far ridges
    vec3 ridgeBlue = farHazeCol * mix(vec3(0.62, 0.74, 0.92), vec3(0.84, 0.82, 0.86), sunset);
    vec3 aerialCol = mix(ridgeBlue, farHazeCol, smoothstep(140.0, 520.0, dist));

    // Composite: marine bank -> patchy slope wisps -> layered aerial perspective
    // (slightly reduce aerial darkening over bright clouds so wisps stay luminous)
    color = mix(color, marineCol, marine * eyeSky);
    color = mix(color, cloudCol, slopeCloud * outdoor);
    color = mix(color, aerialCol, haze * (1.0 - 0.30 * slopeCloud) * eyeSky);

    return color;
}
#endif
#endif

void main() {
    vec3 color = texture(colortex0, texcoord).rgb;
    if (any(isnan(color)) || any(isinf(color))) color = vec3(0.0);
    float depth0 = texture(depthtex0, texcoord).r;
    vec4 data = texture(colortex1, texcoord);

    vec3 viewPos = screenToView(texcoord, depth0);
    bool farLand = false;   // a Distant Horizons pixel (only where no normal terrain was drawn)
#ifdef DISTANT_HORIZONS
    if (depth0 >= 1.0) {
        float dh0 = texture(dhDepthTex0, texcoord).r;
        if (dh0 < 1.0) {
            farLand = true;
            viewPos = dhScreenToView(texcoord, dh0);
            data = vec4(0.0);   // nothing from the normal water pass belongs to this pixel
            float dh1 = texture(dhDepthTex1, texcoord).r;
            if (dh1 > dh0 && isEyeInWater == 0)
                color = renderFarWater(color, viewPos, dhScreenToView(texcoord, dh1), normalize(viewPos));
        }
    }
#endif
    float dist = length(viewPos);
    vec3 viewDir = normalize(viewPos);

    // depth0 < 0.56 is the player's hand, which is never water
    bool isWater = data.a > 0.1 && depth0 >= 0.56;

#ifdef WORLD_OUTLINE
    // soft dark outlines where a block edge stands in front of something further away (silhouettes and
    // corners), within 64 blocks. Four depth taps; distances compared relative to depth so it scales.
    if (depth0 < 1.0 && depth0 >= 0.56 && !isWater && !farLand) {
        vec2 px = 1.0 / vec2(viewWidth, viewHeight);
        float zc = -viewPos.z;
        float zs[4] = float[4](
            -screenToView(texcoord + vec2(px.x, 0.0), texture(depthtex0, texcoord + vec2(px.x, 0.0)).r).z,
            -screenToView(texcoord - vec2(px.x, 0.0), texture(depthtex0, texcoord - vec2(px.x, 0.0)).r).z,
            -screenToView(texcoord + vec2(0.0, px.y), texture(depthtex0, texcoord + vec2(0.0, px.y)).r).z,
            -screenToView(texcoord - vec2(0.0, px.y), texture(depthtex0, texcoord - vec2(0.0, px.y)).r).z);
        float edge = 0.0;
        for (int i = 0; i < 4; i++) edge += clamp((zs[i] - zc) / (zc * 0.06 + 0.15) - 0.5, 0.0, 1.0);
        edge = clamp(edge * 0.5, 0.0, 1.0) * (1.0 - smoothstep(32.0, 64.0, zc));
        color *= 1.0 - edge * 0.38 * WORLD_OUTLINE_STRENGTH;
    }
#endif

    vec2 extra = texture(colortex2, texcoord).rg;
    bool fromBelow = data.a > 0.5 && isEyeInWater == 1 && !farLand;   // the wave mod moves isEyeInWater with the waves
    if (isWater && fromBelow && isEyeInWater != 2) {
        color = renderUnderside(color, data, viewDir);
    } else if (isWater && isEyeInWater == 0) {
        color = renderWater(color, data, depth0, viewPos, viewDir, dist, extra.r);
    }

#ifdef WATER_HOLE_DEBUG
    // a surface under the sea level, seen from above it, with no water drawn over it = a hole in the water
    {
        vec3 wpD = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
        if (!isWater && depth0 < 1.0 && !farLand && isEyeInWater == 0 && cameraPosition.y > 63.0
            && wpD.y < 62.8 && wpD.y > 45.0 && dist < 96.0) color = vec3(4.0, 0.0, 4.0);
    }
#endif
    if (isEyeInWater == 1) {
        // underwater: soft blue-green haze
        vec3 uwCol = vec3(0.012, 0.065, 0.08) * (getAmbientColor() * 2.4 + getDirectLightColor() * 0.2 + 0.03);
        vec3 transmit = exp(-vec3(0.30, 0.08, 0.06) * dist / WATER_CLARITY);
        color = color * transmit + uwCol * (1.0 - exp(-dist * 0.12 / WATER_CLARITY));
    } else if (isEyeInWater == 2) {
        color = mix(color, vec3(1.2, 0.35, 0.05), 1.0 - exp(-dist * 0.8));
    } else if (depth0 < 1.0 || farLand) {
        // atmospheric haze; a little thicker at sunrise/sunset and in rain
        float eyeSky = eyeBrightnessSmooth.y / 240.0;
        vec3 fogCol = getSkyColor(viewDir);
    #if !defined NETHER && !defined END
        float h = getSunHeight();
        float sunset = getSunsetFactor(h);
        vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;

    #if LOOK_STYLE == 1
        color = pnwAtmosphere(color, worldPos, viewDir, dist, eyeSky, h, sunset);
    #else
        // aerial perspective: distant land fades into blue-lavender haze,
        // glowing warm when you look toward a low sun
        vec3 hazeCol = horizonHaze(viewDir, eyeSky);
        // clear for the first ~40 blocks, then a thick sea haze: far islands fade into it
        float density = (0.0042 + 0.0030 * sunset + 0.008 * rainStrength) * FOG_DENSITY * LOOK_HAZE_MUL;
        float haze = 1.0 - exp(-max(dist - LOOK_HAZE_START, 0.0) * density);

        // valley mist: thick and low near sea level, strongest in the morning
        float morning = (worldTime > 22500 || worldTime < 2500) ? 1.0 : 0.0;
        // the islands all sit right on sea level, so the mist is light by day and only thick on mornings and in rain
        float forestFogBoost = (0.45 + 0.55 * clamp(rainStrength + (1.0 - smoothstep(0.05, 0.45, h)), 0.0, 1.0)) * LOOK_FOREST_FOG;
        float mistAmount = (0.06 + 0.45 * morning + rainStrength * 0.5 + forestFogBoost) * VALLEY_MIST * LOOK_MIST_MUL;
        const float mistFalloff = 0.06;
        float y0 = cameraPosition.y - 62.0, y1 = worldPos.y - 62.0;
        float dy = y1 - y0;
        float avgMist = abs(dy) < 0.5
            ? exp(-mistFalloff * max(y0, 0.0))
            : (exp(-mistFalloff * max(y0, 0.0)) - exp(-mistFalloff * max(y1, 0.0))) / (mistFalloff * dy);
        float mist = (1.0 - exp(-dist * clamp(avgMist, 0.0, 1.0) * 0.014 * mistAmount)) * 0.85;
        vec3 mistCol = (vec3(luminance(getAmbientColor())) * vec3(0.82, 0.90, 1.0) * 1.4 + getDirectLightColor() * 0.06) * LOOK_MIST_TINT;

        mistCol = mix(vec3(0.004, 0.005, 0.007), mistCol, eyeSky);
        color = mix(color, mistCol, mist * eyeSky);
        // mountain cloud: the peaks (Mount Ashen, the mainland ranges) sit in a layer of low cloud.
        // Thicker the higher the ground, and you're inside it when you climb up there.
        float hiP = smoothstep(LOOK_CLOUD_Y_LOW, LOOK_CLOUD_Y_HIGH, worldPos.y), hiC = smoothstep(LOOK_CLOUD_Y_LOW, LOOK_CLOUD_Y_HIGH, cameraPosition.y);
        float peakCloud = 1.0 - exp(-dist * 0.010 * LOOK_CLOUD_MUL * max(hiP, 0.6 * hiC) * (1.0 + rainStrength));
        vec3 cloudCol = mix(vec3(0.004, 0.005, 0.007), vec3(luminance(getAmbientColor())) * vec3(0.90, 0.94, 1.0) * 1.5 + getDirectLightColor() * 0.10, max(eyeSky, 0.5));
        color = mix(color, cloudCol, peakCloud * 0.9);
        color = mix(color, hazeCol, haze);
    #endif
        // the edge of the loaded world: measured flat (chunks load in a square, not a sphere) and faded
        // into the sky colour behind it, so the end of the render distance melts into the horizon
        float flatDist = length(worldPos.xz - cameraPosition.xz);
    #ifdef DISTANT_HORIZONS
        // with Distant Horizons the world ends much further out: start the fade sooner and make it long and soft,
        // so the far islands sink into the sea haze instead of stopping at a line
        // Does Distant Horizons have far land behind this pixel? If not (it builds its far views slowly, so in a new
        // area there often isn't any yet), the world really ends at the normal render distance: fade out there.
        // just after a teleport Distant Horizons' far land is still placed for the old position: don't trust it
        float settle = smoothstep(0.03, 0.25, hearthSettle);
        bool dhGoesOn = (farLand || texture(dhDepthTex0, texcoord).r < 1.0) && settle < 0.5;
        float edge = dhGoesOn ? max(float(dhRenderDistance), far) : far;
        float border = dhGoesOn ? smoothstep(edge * (EDGE_FOG_START - 0.2), edge * 0.95, flatDist)
                                : smoothstep(edge * EDGE_FOG_START, edge * 0.97, flatDist);
    #else
        float edge = far;
        float border = smoothstep(edge * EDGE_FOG_START, edge * 0.97, flatDist);
    #endif
        color = mix(color, horizonHaze(viewDir, max(eyeSky, 0.35)), border * border * (3.0 - 2.0 * border));
    #ifdef DISTANT_HORIZONS
        if (farLand) color = mix(color, horizonHaze(viewDir, max(eyeSky, 0.35)), settle);   // hide misplaced far land, then fade it back in
    #endif
    #else
        float density = 0.006 * FOG_DENSITY;
        float haze = 1.0 - exp(-dist * density);
        float border = smoothstep(far * 0.55, far, dist);
        color = mix(color, fogCol, max(haze, border * border));
    #endif
    }

#if !defined NETHER && !defined END
    if (depth0 >= 1.0 && !farLand && isEyeInWater == 0) {
        // the sky near and below the horizon: the same haze the far sea fades into, so there's no line where the
        // world ends (and no strip of blue sky showing under the horizon behind the last chunks)
        vec3 wDir = normalize(mat3(gbufferModelViewInverse) * viewDir);
        float dirY = wDir.y;
        float eyeSkyS = eyeBrightnessSmooth.y / 240.0;
    #if LOOK_STYLE == 1
        float hSky = getSunHeight();
        float nightS = getNightFactor(hSky);
        float sunsetS = getSunsetFactor(hSky);
        vec2 skyUv = wDir.xz / (max(dirY, 0.0) + 0.28);
        float skyNoise = valueNoise(skyUv * 1.15 + vec2(frameTimeCounter * 0.008, frameTimeCounter * 0.003));
        float deckMask = smoothstep(0.02, 0.32, dirY);
        // Clear days: patchy slate deck leaving pale blue breaks; rain: solid darker ceiling
        float deckCover = mix(smoothstep(0.22, 0.82, skyNoise) * 0.62 + 0.20, 0.92, rainStrength);
        float skyLumS = luminance(color);
        vec3 slateDeck = vec3(skyLumS) * mix(vec3(0.76, 0.85, 0.98), vec3(0.60, 0.68, 0.78), rainStrength);
        slateDeck = mix(slateDeck, color, 0.25 + 0.45 * sunsetS);
        color = mix(color, slateDeck, deckMask * deckCover * (1.0 - nightS * 0.85));
    #endif
        color = mix(color, horizonHaze(viewDir, max(eyeSkyS, 0.35)), smoothstep(0.12, -0.02, dirY) * HORIZON_HAZE);
    }
#endif
    if (any(isnan(color)) || any(isinf(color))) color = vec3(0.0);
    color = max(color, 0.0);
    // limit very bright pixels (sun sparkles etc.) so the bloom can't turn them into squares
    float lum = luminance(color);
    if (lum > 12.0) color *= 12.0 / lum;
    outColor = vec4(color, 1.0);
}

#endif

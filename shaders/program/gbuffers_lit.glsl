// Shared by terrain, entities, block entities, hand and particles.
// Options: TERRAIN, ENTITIES, HAND (implies NO_SHADOWS), NO_NORMAL
#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#if defined TERRAIN && defined VERTEX && defined REAL_WAVES
// kelp and seagrass stay under the Realistic Waves surface instead of poking out of a trough
#define RW_SAMPLE_FIELD
#define RW_FAR_ONLY
#include "/lib/realwaves.glsl"
#endif

#ifdef HAND
    #define NO_SHADOWS
#endif

#ifdef VERTEX

#ifdef TERRAIN
in vec4 mc_Entity;
in vec2 mc_midTexCoord;
#include "/lib/waving.glsl"
#endif

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 playerPos;
out vec3 worldNormal;
out vec3 viewNormal;
flat out int blockId;
#ifdef TERRAIN
out vec4 tileBounds;   // xy = this block texture's corner in the atlas, zw = its size (same at every corner of a face)
#endif

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
#ifdef TERRAIN
    vec2 tileHalf = texcoord - mc_midTexCoord;
    tileBounds = vec4(min(texcoord, mc_midTexCoord - tileHalf), abs(tileHalf) * 2.0);
#endif
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = clamp(lmcoord * 33.05 / 32.0 - 1.05 / 32.0, 0.0, 1.0);
    glcolor = gl_Color;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    playerPos = (gbufferModelViewInverse * viewPos).xyz;

#ifdef TERRAIN
    blockId = int(mc_Entity.x + 0.5);
    vec3 restPos = playerPos;   // before swaying: the plant's real block (used to keep water plants under the waves)
    #ifdef WAVING_PLANTS
    bool isTop = gl_MultiTexCoord0.t < mc_midTexCoord.t;
    vec3 wave = getWaveOffset(playerPos + cameraPosition, blockId, isTop);
    if (wave != vec3(0.0)) {
        playerPos += wave;
        viewPos = gbufferModelView * vec4(playerPos, 1.0);
    }
    #endif
    #ifdef REAL_WAVES
    // kelp and seagrass: only the TOP of each plant block bends down under a passing trough, never below the
    // block's own bottom (it used to fold through itself and flicker), and only where the drawn sea has waves
    if (blockId == ID_WATER_PLANT && gl_MultiTexCoord0.t < mc_midTexCoord.t) {
        float d = length(restPos.xz);
        if (d < WAVE_RANGE) {
            float fade = smoothstep(WAVE_RANGE, WAVE_RANGE * 0.7, d);   // same fade as the water surface
            float limit = mix(1e4, rw_keep_under(restPos).y, fade);     // from the unswayed position: no snapping between columns
            float bottom = floor(restPos.y + cameraPosition.y - 0.01) - cameraPosition.y + 0.2;
            playerPos.y = max(min(playerPos.y, limit), bottom);
            viewPos = gbufferModelView * vec4(playerPos, 1.0);
        }
    }
    #endif
#else
    blockId = 0;
#endif

    vec3 vn = gl_NormalMatrix * gl_Normal;
    viewNormal = dot(vn, vn) > 1e-8 ? normalize(vn) : vec3(0.0, 0.0, 1.0);
    worldNormal = mat3(gbufferModelViewInverse) * viewNormal;

    gl_Position = gl_ProjectionMatrix * viewPos;
}

#endif

#ifdef FRAGMENT

uniform sampler2D gtexture;
#ifdef ENTITIES
uniform vec4 entityColor;
#endif

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 playerPos;
in vec3 worldNormal;
in vec3 viewNormal;
flat in int blockId;
#ifdef TERRAIN
in vec4 tileBounds;
uniform ivec2 atlasSize;
#endif

#include "/lib/sky.glsl"
#ifndef NO_SHADOWS
#include "/lib/shadows.glsl"
#endif
#include "/lib/lighting.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec4 albedo = texture(gtexture, texcoord) * glcolor;
#ifdef ENTITIES
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
#endif
    if (albedo.a < 0.1) discard;

    albedo.rgb = toLinear(albedo.rgb);

#ifdef NO_NORMAL
    bool hasNormal = false;
#else
    bool hasNormal = true;
#endif
    vec3 n = gl_FrontFacing ? viewNormal : -viewNormal;
    vec3 wn = mat3(gbufferModelViewInverse) * n;

#ifdef TERRAIN
    // where we are inside this block's texture (0..1), and how many texels it has
    vec2 tileSize = max(tileBounds.zw, vec2(1e-6));
    vec2 tilePx = max(tileSize * vec2(atlasSize), vec2(1.0));
    vec2 local = clamp((texcoord - tileBounds.xy) / tileSize, 0.0, 1.0);
    float dist = length(playerPos);
    #ifdef COATED_TEXTURES
    // a faint, texel-locked grain: lighter and darker specks, strongest up close
    float grain = hash12(floor(local * tilePx) + floor(tileBounds.xy * 4096.0));
    albedo.rgb *= 1.0 + (grain - 0.5) * 0.10 * (1.0 - smoothstep(24.0, 64.0, dist));
    #endif
    #ifdef GENERATED_NORMALS
    // bumps from the texture's own brightness (darker texels = lower), sampled inside the same tile so
    // neighbouring atlas textures never bleed in. Derivatives are taken before any branching.
    vec3 dpx = dFdx(playerPos), dpy = dFdy(playerPos);
    vec2 dux = dFdx(texcoord), duy = dFdy(texcoord);
    float fade = (1.0 - smoothstep(20.0, 40.0, dist)) * GEN_NORMAL_STRENGTH;
    if (fade > 0.001 && blockId != ID_WATER) {
        vec2 texStep = 1.0 / tilePx;
        float h0 = luminance(textureLod(gtexture, tileBounds.xy + local * tileSize, 0.0).rgb);
        float hx = luminance(textureLod(gtexture, tileBounds.xy + fract(local + vec2(texStep.x, 0.0)) * tileSize, 0.0).rgb);
        float hy = luminance(textureLod(gtexture, tileBounds.xy + fract(local + vec2(0.0, texStep.y)) * tileSize, 0.0).rgb);
        vec2 grad = vec2(hx - h0, hy - h0) * 1.6 * fade;
        // tangent frame from screen-space derivatives (no tangent attribute needed)
        vec3 N = normalize(wn);
        vec3 c1 = cross(dpy, N), c2 = cross(N, dpx);
        vec3 T = c1 * dux.x + c2 * duy.x;
        vec3 B = c1 * dux.y + c2 * duy.y;
        float invMax = inversesqrt(max(max(dot(T, T), dot(B, B)), 1e-12));
        vec3 bumped = normalize(N - (T * invMax) * grad.x - (B * invMax) * grad.y);
        if (all(equal(bumped, bumped))) {   // NaN guard
            wn = bumped;
            n = mat3(gbufferModelView) * wn;
        }
    }
    #endif
#endif

    vec3 lit = computeLighting(albedo.rgb, playerPos, wn, n, lmcoord, blockId, hasNormal);
    outColor = vec4(lit, albedo.a);
}

#endif

// Translucent blocks: water, stained glass, ice, slime...
// Water itself is drawn almost invisibly here; composite.glsl does the real work
// (refraction, depth colour, reflections, sun glint) using the data written to colortex1.
#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"
#include "/lib/swell.glsl"
// Realistic Waves (from the Boats N Waves mod, MIT licence, see lib/LICENSE_realwaves.txt): the same waves the boats ride.
// The mod hands its sea state to Iris as rw_* uniforms; without the mod rw_params0.x is 0 and Hearth's own swell is used.
#ifdef VERTEX
#define RW_SAMPLE_FIELD
#endif
#if !defined BOAT_WAKES
#define RW_FAR_ONLY      // leaves out the mod's drawn boat wakes (they looked fake here and cost a texture unit)
#endif
#include "/lib/realwaves.glsl"

#ifdef VERTEX

in vec4 mc_Entity;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 playerPos;
out vec3 viewNormal;
flat out int blockId;
out vec3 rwRest;             // the water surface point before the waves move it
out vec4 rwV0, rwV1, rwV2, rwV3;   // local wave parameters for the fragment stage (rw_pack)
out vec3 rwNormal;           // Fast quality: the wave normal worked out at this block corner
out float rwFoam;            // Fast quality: foam at this block corner

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = clamp(lmcoord * 33.05 / 32.0 - 1.05 / 32.0, 0.0, 1.0);
    glcolor = gl_Color;
    blockId = int(mc_Entity.x + 0.5);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    playerPos = (gbufferModelViewInverse * viewPos).xyz;

    rwRest = playerPos;
    rwV0 = vec4(0.0); rwV1 = vec4(0.0); rwV2 = vec4(0.0); rwV3 = vec4(0.0);
    rwNormal = vec3(0.0, 1.0, 0.0); rwFoam = 0.0;
#ifdef REAL_WAVES
    if (blockId == ID_WATER && rw_active()) {
    #if WAVE_QUALITY == 0
        // Fast: work the waves out once per block corner (a few hundred thousand corners instead of
        // millions of pixels) and let the fragment stage blend between them
        // Only within WAVE_RANGE: past it the sea fades to calm, so far-off ocean costs nothing
        vec3 sp = playerPos;
        float d = length(sp.xz);
        if (d < WAVE_RANGE && rw_is_surface_vertex(sp)) {
            float level = floor(sp.y + cameraPosition.y);
            RwLocal rwl;
            if (rw_local_at(sp, level, rwl)) {
                RwSurface rws = rw_eval(sp.xz, rwl, 0.0, false);
                // over shallow water a trough can't go below the sea floor: it used to dip under the sand,
                // so patches of sand and seagrass flicked in and out of the water as waves passed
                rws.offset.y = max(rws.offset.y, -rw_max_down(rwl));
                rws.offset.xz *= rw_side_damp(rwl);
                float fade = smoothstep(WAVE_RANGE, WAVE_RANGE * 0.7, d);
                playerPos = sp + rws.offset * fade;
                viewPos = gbufferModelView * vec4(playerPos, 1.0);
                rwNormal = normalize(mix(vec3(0.0, 1.0, 0.0), rws.normal, fade));
                float foamR = min(WAVE_RANGE, 56.0);   // whitecaps worked out within 56 blocks (they fade out before that anyway)
                rwFoam = (WAVE_FOAM > 0.0 && d < foamR) ? rw_foam(sp.xz, rwl, rws) * WAVE_FOAM * smoothstep(foamR, foamR * 0.7, d) : 0.0;
                if (!(rwFoam >= 0.0 && rwFoam < 100.0)) rwFoam = 0.0;   // NaN-proof
                rwV2.x = 1.0;   // marks "the mod's waves are here"
            }
        }
    #else
        // Full: pass the local wave parameters on, and work out every detail per pixel
        vec3 sp = playerPos;
        RwLocal rwl;
        if (rw_displace(sp, rwl)) {
            playerPos = sp;
            viewPos = gbufferModelView * vec4(playerPos, 1.0);
            rw_pack(rwl, rwV0, rwV1, rwV2, rwV3);
        }
    #endif
    }
#endif
#ifdef WATER_SWELL_ON
    // Hearth's own swell, only when the wave mod isn't running: roll the top of the water, only downward
    if (blockId == ID_WATER && gl_Normal.y > 0.5 && !rw_active()) {
        vec3 wp = playerPos + cameraPosition;
        vec2 g;
        float h = swellWave(wp.xz, frameTimeCounter, g);
        playerPos.y -= swellAmount(wp.y) * h;
        viewPos = gbufferModelView * vec4(playerPos, 1.0);
    }
#endif
    vec3 vn = gl_NormalMatrix * gl_Normal;
    viewNormal = dot(vn, vn) > 1e-8 ? normalize(vn) : vec3(0.0, 1.0, 0.0);

    gl_Position = gl_ProjectionMatrix * viewPos;
}

#endif

#ifdef FRAGMENT

uniform sampler2D gtexture;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 playerPos;
in vec3 viewNormal;
flat in int blockId;
in vec3 rwRest;
in vec4 rwV0, rwV1, rwV2, rwV3;
in vec3 rwNormal;
in float rwFoam;

#include "/lib/sky.glsl"
#include "/lib/shadows.glsl"
#include "/lib/lighting.glsl"
#include "/lib/water.glsl"

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outData;
layout(location = 2) out vec4 outFoam;   // r: whitecaps and breaking surf, g: 1 = water surface seen from below

void main() {
    vec3 n = gl_FrontFacing ? viewNormal : -viewNormal;
    outFoam = vec4(0.0);
    // size of this pixel on the water, so the finest ripples don't shimmer (worked out before any branching)
    rw_footprint = max(length(dFdx(rwRest.xz)), length(dFdy(rwRest.xz)));

    if (blockId == ID_WATER) {
        vec3 wn = mat3(gbufferModelViewInverse) * n;
        bool isTop = abs(wn.y) > 0.5;

    #ifdef REAL_WAVES
        bool rwHere = isTop && rw_active() && rwV2.x > 1e-3;
    #else
        bool rwHere = false;
    #endif
    #ifdef REAL_WAVES
        if (rwHere) {
        #if WAVE_QUALITY == 0
            // Fast: the big waves come blended from the block corners; Hearth's cheap ripples add the fine detail
            vec3 waveN = normalize(rwNormal);
            vec3 rip = getWaterNormal(playerPos.xz + cameraPosition.xz, length(playerPos));
            float wy = max(waveN.y, 0.25), ry = max(rip.y, 0.25);   // steep crests: no divide-by-almost-zero
            waveN = normalize(vec3(waveN.x / wy + 0.6 * rip.x / ry, 1.0, waveN.z / wy + 0.6 * rip.z / ry));
            if (wn.y < 0.0) waveN.y = -waveN.y;
            n = mat3(gbufferModelView) * waveN;
            outFoam = vec4(clamp(rwFoam, 0.0, 1.0), 0.0, 0.0, 1.0);
        #else
            // the mod's waves: the same shape the boats ride, plus whitecaps and surf
            RwLocal rwl = rw_unpack(rwV0, rwV1, rwV2, rwV3);
            // full detail (ripples, slicks, micro waves) only close by; further out just the real waves,
            // which is much cheaper in storms when every wave layer is active
            float rwDist = length(rwRest);
            RwSurface rws = rw_eval(rwRest.xz, rwl, 0.0, rwDist < WAVE_DETAIL_DIST);
            vec3 waveN = normalize(rws.normal);
            if (wn.y < 0.0) waveN.y = -waveN.y;
            n = mat3(gbufferModelView) * waveN;
            float foam = (WAVE_FOAM > 0.0 && rwDist < 160.0) ? rw_foam(rwRest.xz, rwl, rws) * WAVE_FOAM * smoothstep(160.0, 120.0, rwDist) : 0.0;
            outFoam = vec4(clamp(foam, 0.0, 1.0), 0.0, 0.0, 1.0);
        #endif
        }
    #endif
    #ifdef WATER_WAVES
        if (isTop && !rwHere) {
            vec3 waveN = getWaterNormal(playerPos.xz + cameraPosition.xz, length(playerPos));
        #ifdef WATER_SWELL_ON
            // tilt the surface with the swell as well as the small ripples
            vec3 wpS = playerPos + cameraPosition;
            vec2 gS;
            swellWave(wpS.xz, frameTimeCounter, gS);
            float aS = rw_active() ? 0.0 : swellAmount(wpS.y);
            waveN = normalize(vec3(waveN.x / waveN.y + aS * gS.x, 1.0, waveN.z / waveN.y + aS * gS.y));
        #endif
            if (wn.y < 0.0) waveN.y = -waveN.y;
            n = mat3(gbufferModelView) * waveN;
        }
    #endif

        if (isTop) {
            // invisible here; composite draws the surface
            outColor = vec4(0.0);
        } else {
            // waterfalls and the sides of flowing water keep a hint of the
            // vanilla texture so you can still see them moving
            vec4 tex = texture(gtexture, texcoord);
            float detail = luminance(tex.rgb);
            vec3 light = getAmbientColor() * lmcoord.y * lmcoord.y + getDirectLightColor() * 0.15 + getTorchLight(lmcoord.x) * 0.5;
            outColor = vec4(vec3(0.20, 0.42, 0.45) * detail * light * 1.5, 0.30);
        }
        // a: > 0.5 means water top surface, 0.1..0.5 means water side
        float mask = isTop ? 0.6 + 0.4 * lmcoord.y : 0.15 + 0.3 * lmcoord.y;
        outData = vec4(encodeNormal(n), lmcoord.x, mask);
        // remember when we're looking at the surface from underneath (under a wave, or swimming)
        // only a real "from below" when the surface is above your eyes: tilted wave faces seen at a grazing angle
        // from above can also face away from the camera, and used to paint dark boxes over swimmers
        bool belowSurface = isTop && !gl_FrontFacing && playerPos.y > -0.05;
        outFoam = vec4(outFoam.r, belowSurface ? 1.0 : 0.0, 0.0, 1.0);
    } else {
        vec4 albedo = texture(gtexture, texcoord) * glcolor;
        if (albedo.a < 0.02) discard;
        albedo.rgb = toLinear(albedo.rgb);
        vec3 wn = mat3(gbufferModelViewInverse) * n;
        vec3 lit = computeLighting(albedo.rgb, playerPos, wn, n, lmcoord, blockId, true);
        outColor = vec4(lit, albedo.a);
        outData = vec4(0.0);
    }
}

#endif

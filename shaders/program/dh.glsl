// Distant Horizons: the far-away simplified terrain (LODs) beyond the normal render distance.
// DH_TERRAIN: lit like normal terrain (the LODs carry one colour per block face, no texture).
// DH_WATER: draws nothing itself; composite.glsl paints far water from the two DH depth buffers.
#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

#ifdef VERTEX

out vec2 lmcoord;
out vec4 glcolor;
out vec3 playerPos;
out vec3 viewNormal;
flat out int materialId;

void main() {
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = clamp(lmcoord * 33.05 / 32.0 - 1.05 / 32.0, 0.0, 1.0);
    glcolor = gl_Color;
    materialId = dhMaterialId;
    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    playerPos = (gbufferModelViewInverse * viewPos).xyz;
    vec3 vn = gl_NormalMatrix * gl_Normal;
    viewNormal = dot(vn, vn) > 1e-8 ? normalize(vn) : vec3(0.0, 1.0, 0.0);
    gl_Position = gl_ProjectionMatrix * viewPos;
}

#endif

#ifdef FRAGMENT

in vec2 lmcoord;
in vec4 glcolor;
in vec3 playerPos;
in vec3 viewNormal;
flat in int materialId;

#ifdef DH_TERRAIN
#include "/lib/sky.glsl"
#include "/lib/shadows.glsl"
#include "/lib/lighting.glsl"
#endif

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    // the normal chunks cover everything inside the render distance; only draw beyond it
    // (a small overlap hides the seam; normal terrain draws over the LODs anyway)
    if (length(playerPos.xz) < far - 16.0) discard;

#ifdef DH_TERRAIN
    vec3 albedo = toLinear(glcolor.rgb);
    // a little per-block variation so far forests and slopes aren't flat colour
    vec3 wp = floor(playerPos + cameraPosition + 0.001);
    float v = fract(sin(dot(wp, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
    albedo *= 0.92 + 0.16 * v;
    vec3 n = gl_FrontFacing ? viewNormal : -viewNormal;
    vec3 wn = mat3(gbufferModelViewInverse) * n;
    int id = (materialId == DH_BLOCK_LEAVES) ? ID_LEAVES : 0;
    outColor = vec4(computeLighting(albedo, playerPos, wn, n, lmcoord, id, true), 1.0);
#else
    outColor = vec4(0.0);   // far water: painted in composite
#endif
}

#endif

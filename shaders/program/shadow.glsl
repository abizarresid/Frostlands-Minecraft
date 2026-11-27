#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

#ifdef VERTEX

in vec4 mc_Entity;
in vec2 mc_midTexCoord;
#include "/lib/waving.glsl"

out vec2 texcoord;
out vec4 glcolor;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    vec4 playerPos = shadowModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
#ifdef WAVING_PLANTS
    bool isTop = gl_MultiTexCoord0.t < mc_midTexCoord.t;
    playerPos.xyz += getWaveOffset(playerPos.xyz + cameraPosition, int(mc_Entity.x + 0.5), isTop);
#endif
    gl_Position = shadowProjection * (shadowModelView * playerPos);
    gl_Position.xyz = distortShadow(gl_Position.xyz);
}

#endif

#ifdef FRAGMENT

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < 0.1) discard;
    outColor = c;
}

#endif

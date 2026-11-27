// BASIC: untextured lines (block outline, leads). GLINT: enchant glint. Otherwise: spider eyes, beacon beams.
#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

#ifdef VERTEX

out vec2 texcoord;
out vec4 glcolor;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    gl_Position = ftransform();
}

#endif

#ifdef FRAGMENT

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
#ifdef BASIC
    outColor = vec4(toLinear(glcolor.rgb), glcolor.a);
#else
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < 0.01) discard;
    #ifdef GLINT
    outColor = vec4(toLinear(c.rgb), c.a);
    #else
    outColor = vec4(toLinear(c.rgb) * 1.8, c.a);
    #endif
#endif
}

#endif

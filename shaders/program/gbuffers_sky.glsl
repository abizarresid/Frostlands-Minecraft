// SKY_BASIC: the sky dome + procedural stars. SKY_TEXTURED: procedural moon. CLOUDS. WEATHER.
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
uniform int renderStage;

in vec2 texcoord;
in vec4 glcolor;

#include "/lib/sky.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
#if defined SKY_BASIC
    #ifdef MC_RENDER_STAGE_STARS
    // Vanilla square stars are replaced by cheap twinkling procedural stars below
    if (renderStage == MC_RENDER_STAGE_STARS) discard;
    #endif
    vec2 uv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    vec3 dir = normalize(screenToView(uv, 1.0));
    #if CLOUD_QUALITY == 0
    const int cloudSteps = 6;
    #elif CLOUD_QUALITY == 1
    const int cloudSteps = 10;
    #else
    const int cloudSteps = 14;
    #endif
    vec4 clouds = getClouds(dir, cloudSteps, ign(gl_FragCoord.xy));
    vec3 skyCol = getSkyColor(dir) + getSunDisc(dir) + getStars(dir);
    outColor = vec4(skyCol * clouds.a + clouds.rgb, 1.0);

#elif defined SKY_TEXTURED
    #ifdef MC_RENDER_STAGE_SUN
    // the sun is drawn as a round disc in the sky shader instead
    if (renderStage == MC_RENDER_STAGE_SUN) discard;
    #endif

    vec2 uv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    vec3 dir = normalize(screenToView(uv, 1.0));
    bool isMoon = dot(dir, normalize(moonPosition)) > 0.90;
    #ifdef MC_RENDER_STAGE_MOON
    isMoon = isMoon || (renderStage == MC_RENDER_STAGE_MOON);
    #endif

    if (isMoon) {
        vec4 moon = getMoonDisc(dir);
        if (moon.a <= 0.001) discard;
        outColor = moon;
        return;
    }

    vec4 c = texture(gtexture, texcoord) * glcolor;
    outColor = vec4(toLinear(c.rgb) * 1.5, c.a);

#elif defined CLOUDS
    // keep vanilla brightness (it already handles day/night), add a warm sunset tint
    vec3 sun = getDirectLightColor();
    vec3 tint = sun / max(max(sun.r, max(sun.g, sun.b)), 0.001);
    float tintAmount = getSunsetFactor(getSunHeight()) * 0.6;
    vec3 c = toLinear(glcolor.rgb) * mix(vec3(1.0), tint, tintAmount) * 1.05;
    outColor = vec4(c, glcolor.a * 0.85);

#elif defined WEATHER
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < 0.02) discard;
    outColor = vec4(toLinear(c.rgb) * (getAmbientColor() + 0.15), c.a * 0.45);
#endif
}

#endif

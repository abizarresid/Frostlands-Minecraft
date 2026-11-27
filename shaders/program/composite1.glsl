// God rays: light shafts streaming from the sun through gaps in trees and clouds.
#include "/lib/settings.glsl"
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
uniform sampler2D depthtex0;

in vec2 texcoord;

#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
#endif
#include "/lib/sky.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main() {
    vec3 color = texture(colortex0, texcoord).rgb;

#ifdef GODRAYS
#if !defined NETHER && !defined END
    if (isEyeInWater == 0 && shadowLightPosition.z < 0.0) {
        vec2 lightUV = viewToScreen(shadowLightPosition).xy;
        const int SAMPLES = 7;   // dithered, so 7 looks like 10 and costs less on every pixel
        vec2 delta = (lightUV - texcoord) / float(SAMPLES) * 0.85;
        vec2 coord = texcoord + delta * ign(gl_FragCoord.xy);

        float rays = 0.0;
        float weight = 1.0;
        for (int i = 0; i < SAMPLES; i++) {
            if (coord.x > 0.0 && coord.x < 1.0 && coord.y > 0.0 && coord.y < 1.0) {
            #ifdef DISTANT_HORIZONS
                rays += step(1.0, texture(depthtex0, coord).r) * step(1.0, texture(dhDepthTex0, coord).r) * weight;   // far LOD land blocks the sun too
            #else
                rays += step(1.0, texture(depthtex0, coord).r) * weight;
            #endif
            }
            weight *= 0.875;
            coord += delta;
        }
        rays /= float(SAMPLES);

        vec2 aspect = vec2(viewWidth / viewHeight, 1.0);
        float falloff = exp(-length((texcoord - lightUV) * aspect) * 2.2);
        float h = getSunHeight();
        float strength = (0.35 + getSunsetFactor(h) * 0.9) * (h > 0.0 ? 1.0 : 0.4);
        float eyeSky = eyeBrightnessSmooth.y / 240.0;

        color += getDirectLightColor() * rays * falloff * strength * eyeSky * 0.35 * GODRAY_STRENGTH;
    }
#endif
#endif

    if (any(isnan(color)) || any(isinf(color))) color = vec3(0.0);
    color = max(color, 0.0);
    // limit very bright pixels (sun sparkles etc.) so the bloom can't turn them into squares
    float lum = luminance(color);
    if (lum > 12.0) color *= 12.0 / lum;
    outColor = vec4(color, 1.0);
}

#endif

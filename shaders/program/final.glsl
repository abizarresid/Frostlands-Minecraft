// Bloom, exposure, tone mapping and colour grading.
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

#ifdef BLOOM
const bool colortex0MipmapEnabled = true;   // the blurred copy for bloom (skipped when bloom is off)
#endif
uniform sampler2D colortex0;

in vec2 texcoord;

#include "/lib/sky.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

vec3 acesFilmic(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

vec3 sampleBloomLevel(float lod) {
    vec2 px = exp2(lod) / vec2(viewWidth, viewHeight);
    // 4 bilinear taps placed between texels = a smooth 4x4 tent filter
    vec3 s = textureLod(colortex0, texcoord + vec2(-px.x, -px.y) * 0.75, lod).rgb;
    s += textureLod(colortex0, texcoord + vec2( px.x, -px.y) * 0.75, lod).rgb;
    s += textureLod(colortex0, texcoord + vec2(-px.x,  px.y) * 0.75, lod).rgb;
    s += textureLod(colortex0, texcoord + vec2( px.x,  px.y) * 0.75, lod).rgb;
    return s * 0.25;
}

// Look styles (designed with Gemini 4 Neon from the user's PNW reference photos; Classic is the original grade)
vec3 applyLook(vec3 color, vec2 uv) {
#if LOOK_STYLE == 0
    // Hearth Classic: byte-identical to original grading path
    float greenness = clamp((color.g - max(color.r, color.b)) / max(color.g, 1e-4), 0.0, 1.0);
    color = mix(color, color * vec3(0.62, 0.78, 0.76), greenness * 0.70 * PNW_GRADE);
    float tone = smoothstep(0.06, 0.65, luminance(color));
    vec3 split = mix(vec3(0.90, 0.99, 1.10), vec3(1.05, 1.0, 0.93), tone);
    color *= mix(vec3(1.0), split, PNW_GRADE);
    vec3 sCurve = color * color * (3.0 - 2.0 * color);
    color = mix(color, sCurve, 0.30 * PNW_GRADE);

    float wl = luminance(color);
    vec3 frost = mix(vec3(0.93, 0.98, 1.07), vec3(1.0, 1.0, 1.02), smoothstep(0.35, 0.85, wl));
    color *= mix(vec3(1.0), frost, WINTER_GRADE);
    float redness = clamp((color.r - max(color.g, color.b)) / max(color.r, 1e-4), 0.0, 1.0);
    color = mix(color, color * vec3(1.10, 0.96, 0.94), redness * 0.6 * WINTER_GRADE);

    color *= mix(vec3(1.0), vec3(1.025, 1.0, 0.96), WARMTH);
    float l = luminance(color);
    color = max(mix(vec3(l), color, SATURATION), 0.0);

#if !defined NETHER && !defined END && (SUNRISE_STYLE != 0 || MORNING_STYLE != 0 || MIDDAY_STYLE != 0 || AFTERNOON_STYLE != 0 || SUNSET_STYLE != 0 || NIGHT_STYLE != 0)
    float todH = getSunHeight();
    #if SUNRISE_STYLE == 1
    {
        // Rosy pastel dawn: soft blush highlight kiss + cool periwinkle dawn shadow
        float rW = todSunrise(todH) * SUNSET_INTENSITY;
        float rLum = luminance(color);
        float hiW = smoothstep(0.42, 0.86, rLum);
        float shW = 1.0 - smoothstep(0.04, 0.38, rLum);
        color *= mix(vec3(1.0), vec3(1.10, 0.94, 0.97), clamp(hiW * rW * 0.56, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.93, 0.95, 1.07), clamp(shW * rW * 0.50, 0.0, 1.0));
    }
    #elif SUNRISE_STYLE == 2
    {
        // Golden clear dawn: crisp champagne-gold highlights, clean cool morning shadows
        float rW = todSunrise(todH) * SUNSET_INTENSITY;
        float rLum = luminance(color);
        float hiW = smoothstep(0.38, 0.84, rLum);
        float shW = 1.0 - smoothstep(0.04, 0.36, rLum);
        color *= mix(vec3(1.0), vec3(1.12, 1.03, 0.84), clamp(hiW * rW * 0.56, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.92, 0.96, 1.06), clamp(shW * rW * 0.45, 0.0, 1.0));
    }
    #endif
    #if MORNING_STYLE == 1
    {
        // Fresh cool crisp: bright cool clarity, crisp shadows, clean saturation
        float mW = todMorning(todH) * clamp(DAY_INTENSITY, 0.5, 1.5) * (1.0 - rainStrength * 0.65);
        float mLum = luminance(color);
        float mSh = 1.0 - smoothstep(0.06, 0.42, mLum);
        color *= mix(vec3(1.0), vec3(0.92, 0.98, 1.08), clamp(mSh * mW * 0.44, 0.0, 1.0));
        vec3 mc = clamp(color, 0.0, 1.0);
        color = mix(color, mc * mc * (3.0 - 2.0 * mc), clamp(mW * 0.12, 0.0, 0.28));
        color = max(mix(vec3(luminance(color)), color, 1.0 + clamp(mW * 0.06, 0.0, 0.12)), 0.0);
    }
    #elif MORNING_STYLE == 2
    {
        // Misty soft: gentle pale morning haze lift and softer highlights
        float mW = todMorning(todH) * clamp(DAY_INTENSITY, 0.5, 1.5);
        float mLum = luminance(color);
        color = mix(color, vec3(mLum) * vec3(0.98, 0.99, 1.02), clamp(mW * 0.14, 0.0, 0.28));
        vec3 mistLift = vec3(0.014, 0.015, 0.018) * clamp(mW, 0.0, 1.5);
        color = mistLift + color * (1.0 - mistLift);
    }
    #endif
    #if MIDDAY_STYLE == 1
    {
        // Crisp clear day: clean high-clarity contrast, cool shadows, crisp sunlit whites
        float dW = todMidday(todH) * clamp(DAY_INTENSITY, 0.5, 1.5) * (1.0 - rainStrength * 0.70);
        float dLum = luminance(color);
        float dSh = 1.0 - smoothstep(0.06, 0.42, dLum);
        float dHi = smoothstep(0.50, 0.90, dLum);
        color *= mix(vec3(1.0), vec3(0.92, 0.97, 1.08), clamp(dSh * dW * 0.48, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(1.04, 1.03, 1.00), clamp(dHi * dW * 0.42, 0.0, 1.0));
        vec3 dc = clamp(color, 0.0, 1.0);
        color = mix(color, dc * dc * (3.0 - 2.0 * dc), clamp(dW * 0.16, 0.0, 0.35));
        color = max(mix(vec3(luminance(color)), color, 1.0 + clamp(dW * 0.07, 0.0, 0.15)), 0.0);
    }
    #elif MIDDAY_STYLE == 2
    {
        // Soft overcast: bright even silvery tones, gentler shadow contrast
        float dW = todMidday(todH) * clamp(DAY_INTENSITY, 0.5, 1.5);
        float dLum = luminance(color);
        color = mix(color, vec3(dLum) * vec3(0.97, 0.99, 1.03), clamp(dW * 0.18, 0.0, 0.35));
        vec3 overcastLift = vec3(0.014, 0.015, 0.018) * clamp(dW, 0.0, 1.5);
        color = overcastLift + color * (1.0 - overcastLift);
        color = color / (1.0 + 0.06 * clamp(dW, 0.0, 1.5) * max(color - 0.72, 0.0));
    }
    #endif
    #if AFTERNOON_STYLE == 1
    {
        // Warm golden: rich warm highlights with gentle cool-slate shadows
        float aW = todAfternoon(todH) * clamp(DAY_INTENSITY, 0.5, 1.5) * (1.0 - rainStrength * 0.65);
        float aLum = luminance(color);
        float aHi = smoothstep(0.36, 0.84, aLum);
        float aSh = 1.0 - smoothstep(0.05, 0.36, aLum);
        color *= mix(vec3(1.0), vec3(1.10, 1.01, 0.84), clamp(aHi * aW * 0.54, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.95, 0.95, 1.02), clamp(aSh * aW * 0.38, 0.0, 1.0));
    }
    #elif AFTERNOON_STYLE == 2
    {
        // Hazy summer: warm creamy atmospheric lift, slightly softer contrast
        float aW = todAfternoon(todH) * clamp(DAY_INTENSITY, 0.5, 1.5);
        float aLum = luminance(color);
        color *= mix(vec3(1.0), vec3(1.05, 1.01, 0.92), clamp(smoothstep(0.30, 0.85, aLum) * aW * 0.45, 0.0, 1.0));
        vec3 hazeLift = vec3(0.016, 0.014, 0.010) * clamp(aW, 0.0, 1.5);
        color = hazeLift + color * (1.0 - hazeLift);
    }
    #endif
    #if SUNSET_STYLE == 1
    {
        // Rose alpenglow: pastel pink-coral highlight kiss + cool dusk shadow
        float sW = todSunset(todH) * SUNSET_INTENSITY;
        float sLum = luminance(color);
        float sChroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
        float hiPeak = smoothstep(0.48, 0.88, sLum) * (1.0 - smoothstep(0.18, 0.48, sChroma));
        float shLow  = 1.0 - smoothstep(0.05, 0.36, sLum);
        color *= mix(vec3(1.0), vec3(1.14, 0.88, 0.92), clamp(hiPeak * sW * ALPENGLOW * 0.65, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.91, 0.93, 1.06), clamp(shLow * sW * 0.55, 0.0, 1.0));
    }
    #elif SUNSET_STYLE == 2
    {
        // Amber golden hour: warm golden highlights, cool-umber shadow split
        float sW = todSunset(todH) * SUNSET_INTENSITY;
        float sLum = luminance(color);
        float hiW = smoothstep(0.34, 0.82, sLum);
        float shW = 1.0 - smoothstep(0.04, 0.34, sLum);
        color *= mix(vec3(1.0), vec3(1.13, 1.01, 0.80), clamp(hiW * sW * 0.60, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.94, 0.92, 0.95), clamp(shW * sW * 0.50, 0.0, 1.0));
    }
    #endif
    #if NIGHT_STYLE == 1
    {
        // Moonlit mist: soft cool blue lift in shadows
        float nW = todNight(todH);
        float nl = luminance(color);
        color = mix(color, vec3(nl) * vec3(0.88, 0.95, 1.08), nW * 0.22);
        vec3 mistLift = vec3(0.008, 0.014, 0.024) * nW * clamp(NIGHT_FOG, 0.25, 2.0);
        color = mistLift + color * (1.0 - mistLift);
    }
    #elif NIGHT_STYLE == 2
    {
        // Starry clear: slightly deeper crisp indigo-slate night contrast
        float nW = todNight(todH);
        color *= mix(vec3(1.0), vec3(0.92, 0.95, 1.05), nW * 0.45);
        vec3 nc = clamp(color, 0.0, 1.0);
        color = mix(color, nc * nc * (3.0 - 2.0 * nc), nW * 0.18);
    }
    #endif
    color = max(color, 0.0);
#endif

#ifdef VIGNETTE
    vec2 v = uv - 0.5;
    color *= 1.0 - dot(v, v) * 0.35;
#endif
    return color;

#elif LOOK_STYLE == 1
    // PNW Moody: rich wet conifer blue-greens, deep black-green canopy shadows,
    // cool teal-slate shadow split, crisp local contrast, popping warm lights
    float evergreenDepth = (EVERGREEN_DEPTH < 0.0) ? 1.10  : EVERGREEN_DEPTH;
    float shadowCoolness = (SHADOW_COOLNESS < 0.0) ? 0.95  : SHADOW_COOLNESS;
    float blackLift      = (BLACK_LIFT      < 0.0) ? 0.006 : BLACK_LIFT;
    float warmPop        = (WARM_ACCENT_POP < 0.0) ? 0.90  : WARM_ACCENT_POP;
    float moodContrast   = (MOOD_CONTRAST   < 0.0) ? 0.46  : MOOD_CONTRAST;

    // 1) Shift bright/yellow foliage into deep Douglas-fir & cedar blue-green,
    //    while keeping mossy undergrowth rich rather than muddy grey
    float greenness   = clamp((color.g - max(color.r, color.b)) / max(color.g, 1e-4), 0.0, 1.0);
    float yellowGreen = clamp((min(color.r, color.g) - color.b) / max(color.g, 1e-4), 0.0, 1.0)
                      * smoothstep(0.0, 0.16, color.g - color.r * 0.72);
    float foliage = clamp(greenness + yellowGreen * 0.50, 0.0, 1.0);
    vec3 coniferTint = mix(vec3(0.66, 0.84, 0.80), vec3(0.52, 0.79, 0.87), yellowGreen);
    color = mix(color, color * coniferTint, clamp(foliage * 0.72 * evergreenDepth, 0.0, 1.0));

    // 2) Cool slate/teal shadows, clean mids, crisp silvery highlights
    float lum     = luminance(color);
    float shadowW = 1.0 - smoothstep(0.01, 0.30, lum);
    float midW    = smoothstep(0.04, 0.28, lum) * (1.0 - smoothstep(0.46, 0.84, lum));
    float highW   = smoothstep(0.56, 0.94, lum);
    vec3 split    = vec3(1.0)
                  + vec3(-0.14, -0.02,  0.10) * shadowW
                  + vec3(-0.04,  0.01,  0.03) * midW
                  + vec3(-0.01,  0.00,  0.02) * highW;
    color = max(color * mix(vec3(1.0), split, clamp(shadowCoolness, 0.0, 1.5)), 0.0);

    // 3) Protect conifer saturation (no flat grey wash), gently mute neutrals, pop warm accents
    float warmHue = clamp((color.r - color.b) / max(color.r, 1e-4), 0.0, 1.0)
                  * smoothstep(0.02, 0.18, color.r - color.g * 0.55);
    float l0      = luminance(color);
    float baseSat = mix(0.90, 1.05, clamp(foliage * 0.75, 0.0, 1.0));
    float effSat  = mix(baseSat * SATURATION, 1.22 * SATURATION, clamp(warmHue * warmPop, 0.0, 1.0));
    color = max(mix(vec3(l0), color, effSat), 0.0);
    color *= mix(vec3(1.0), vec3(1.12, 1.01, 0.91), clamp(warmHue * 0.55 * warmPop, 0.0, 1.0));

    // 4) Slightly darker mood + crisp S-curve local contrast + light highlight rolloff (keeps wet sheen glossy)
    color *= 0.94;
    vec3 c = clamp(color, 0.0, 1.0);
    vec3 sCurve = c * c * (3.0 - 2.0 * c);
    color = mix(color, sCurve, clamp(moodContrast, 0.0, 0.85));
    color = color / (1.0 + 0.04 * max(color - 0.82, 0.0));

    // 5) Barely lifted cool slate blacks so canopy shadows stay deep black-green
    vec3 liftCol = vec3(0.84, 0.95, 1.08) * clamp(blackLift, 0.0, 0.08);
    color = liftCol + color * (1.0 - liftCol);

    // Respect user WARMTH adjustments relative to default 1.0
    color = max(color * mix(vec3(1.0), vec3(1.03, 1.0, 0.95), WARMTH - 1.0), 0.0);

#if !defined NETHER && !defined END && (SUNRISE_STYLE != 0 || MORNING_STYLE != 0 || MIDDAY_STYLE != 0 || AFTERNOON_STYLE != 0 || SUNSET_STYLE != 0 || NIGHT_STYLE != 0)
    float todH = getSunHeight();
    #if SUNRISE_STYLE == 1
    {
        // Fog-bound grey dawn with pink seam: cool misty veil + subtle rose highlight kiss
        float rW = todSunrise(todH) * SUNSET_INTENSITY;
        float rLum = luminance(color);
        float rHi = smoothstep(0.50, 0.90, rLum);
        color = mix(color, vec3(rLum) * vec3(0.92, 0.96, 1.02), clamp(rW * 0.24, 0.0, 0.42));
        color *= mix(vec3(1.0), vec3(1.12, 0.90, 0.95), clamp(rHi * rW * 0.52, 0.0, 1.0));
        vec3 fogVeil = vec3(0.018, 0.022, 0.028) * clamp(rW, 0.0, 1.5);
        color = fogVeil + color * (1.0 - fogVeil);
    }
    #elif SUNRISE_STYLE == 2
    {
        // Mt. Rainier dawn alpenglow: crisp cool-rose on sunlit peaks, deep slate-blue forest below
        float rW = todSunrise(todH) * SUNSET_INTENSITY;
        float rLum = luminance(color);
        float rChroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
        float snowPeak = smoothstep(0.42, 0.86, rLum) * (1.0 - smoothstep(0.18, 0.50, rChroma));
        float forestSh = 1.0 - smoothstep(0.04, 0.36, rLum);
        color *= mix(vec3(1.0), vec3(1.18, 0.85, 0.93), clamp(snowPeak * rW * ALPENGLOW * 0.76, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.84, 0.90, 1.10), clamp(forestSh * rW * 0.62, 0.0, 1.0));
    }
    #endif
    #if MORNING_STYLE == 1
    {
        // Burning-off marine layer: soft luminous cool mist lift with warm sunlit tops
        float mW = todMorning(todH) * clamp(DAY_INTENSITY, 0.5, 1.5);
        float mLum = luminance(color);
        float mHi = smoothstep(0.46, 0.88, mLum);
        color *= mix(vec3(1.0), vec3(1.06, 1.02, 0.93), clamp(mHi * mW * 0.45, 0.0, 1.0));
        vec3 burnLift = vec3(0.016, 0.020, 0.024) * clamp(mW, 0.0, 1.5);
        color = burnLift + color * (1.0 - burnLift);
    }
    #elif MORNING_STYLE == 2
    {
        // Drizzle grey: muted wet conifer palette, damp cool slate veil
        float mW = todMorning(todH) * clamp(DAY_INTENSITY, 0.5, 1.5);
        float mLum = luminance(color);
        color = mix(color, vec3(mLum) * vec3(0.90, 0.96, 1.02), clamp(mW * 0.32, 0.0, 0.50));
        vec3 drizLift = vec3(0.016, 0.022, 0.026) * clamp(mW, 0.0, 1.5);
        color = drizLift + color * (1.0 - drizLift);
    }
    #endif
    #if MIDDAY_STYLE == 1
    {
        // Sun breaks after rain: wet saturated greens, crisp sunlit highlights, deep storm shadows
        float dW = todMidday(todH) * clamp(DAY_INTENSITY, 0.5, 1.5) * (1.0 - rainStrength * 0.65);
        float dLum = luminance(color);
        float dHi = smoothstep(0.44, 0.86, dLum);
        float dSh = 1.0 - smoothstep(0.03, 0.34, dLum);
        color = max(mix(vec3(dLum), color, 1.0 + clamp(foliage * dW * 0.24, 0.0, 0.36)), 0.0);
        color *= mix(vec3(1.0), vec3(1.08, 1.04, 0.94), clamp(dHi * dW * 0.52, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.90, 0.95, 1.06), clamp(dSh * dW * 0.45, 0.0, 1.0));
        vec3 dc = clamp(color, 0.0, 1.0);
        color = mix(color, dc * dc * (3.0 - 2.0 * dc), clamp(dW * 0.14, 0.0, 0.28));
    }
    #elif MIDDAY_STYLE == 2
    {
        // Marine-layer grey: flat pearly silver veil, softer shadows, muted saturation
        float dW = todMidday(todH) * clamp(DAY_INTENSITY, 0.5, 1.5);
        float dLum = luminance(color);
        color = mix(color, vec3(dLum) * vec3(0.94, 0.98, 1.03), clamp(dW * 0.28, 0.0, 0.48));
        vec3 marineLift = vec3(0.022, 0.026, 0.030) * clamp(dW, 0.0, 1.5);
        color = marineLift + color * (1.0 - marineLift);
        color = color / (1.0 + 0.10 * clamp(dW, 0.0, 1.5) * max(color - 0.68, 0.0));
    }
    #endif
    #if AFTERNOON_STYLE == 1
    {
        // Low-angle forest shafts: warm amber highlights, deep cool-teal canopy shadows
        float aW = todAfternoon(todH) * clamp(DAY_INTENSITY, 0.5, 1.5) * (1.0 - rainStrength * 0.65);
        float aLum = luminance(color);
        float aHi = smoothstep(0.34, 0.84, aLum);
        float aSh = 1.0 - smoothstep(0.03, 0.34, aLum);
        color *= mix(vec3(1.0), vec3(1.14, 1.01, 0.78), clamp(aHi * aW * 0.62, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.88, 0.94, 1.04), clamp(aSh * aW * 0.52, 0.0, 1.0));
        color += vec3(0.026, 0.016, 0.004) * smoothstep(0.28, 0.80, aLum) * clamp(aW, 0.0, 1.5);
    }
    #elif AFTERNOON_STYLE == 2
    {
        // Squally showers: brooding slate-blue gloom with punchy wet foliage contrast
        float aW = todAfternoon(todH) * clamp(DAY_INTENSITY, 0.5, 1.5);
        float aLum = luminance(color);
        color *= mix(vec3(1.0), vec3(0.88, 0.94, 1.06), clamp(aW * 0.42, 0.0, 0.70));
        color = max(mix(vec3(aLum), color, 1.0 + clamp(foliage * aW * 0.18, 0.0, 0.28)), 0.0);
        vec3 ac = clamp(color, 0.0, 1.0);
        color = mix(color, ac * ac * (3.0 - 2.0 * ac), clamp(aW * 0.16, 0.0, 0.30));
    }
    #endif
    #if SUNSET_STYLE == 1
    {
        // Mt. Rainier alpenglow: hot pink-coral on sunlit snow peaks, cool dark forest shadows below
        float sW = todSunset(todH) * SUNSET_INTENSITY;
        float sLum = luminance(color);
        float sChroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
        float snowPeak = smoothstep(0.42, 0.86, sLum) * (1.0 - smoothstep(0.18, 0.50, sChroma));
        float forestSh = 1.0 - smoothstep(0.04, 0.36, sLum);
        color *= mix(vec3(1.0), vec3(1.22, 0.83, 0.89), clamp(snowPeak * sW * ALPENGLOW * 0.78, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.85, 0.89, 1.08), clamp(forestSh * sW * 0.65, 0.0, 1.0));
    }
    #elif SUNSET_STYLE == 2
    {
        // Cascades golden hour: warm gold highlights + hazy golden mid-lift, deep brown-teal shadows
        float sW = todSunset(todH) * SUNSET_INTENSITY;
        float sLum = luminance(color);
        float goldHi = smoothstep(0.30, 0.82, sLum);
        float ridgeSh = 1.0 - smoothstep(0.04, 0.34, sLum);
        color *= mix(vec3(1.0), vec3(1.18, 1.00, 0.72), clamp(goldHi * sW * 0.72, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.88, 0.84, 0.82), clamp(ridgeSh * sW * 0.65, 0.0, 1.0));
        color += vec3(0.045, 0.026, 0.008) * smoothstep(0.25, 0.78, sLum) * clamp(sW, 0.0, 1.5);
    }
    #endif
    #if NIGHT_STYLE == 1
    {
        // Blue hour forest fog: deep cold blue-teal, very low saturation, soft luminous lift (nothing pure black)
        float nW = todNight(todH);
        float nl = luminance(color);
        // (revised: it went flat grey) keep most of the colour, push it into deep blue-teal, keep the darks dark
        color = mix(color, vec3(nl), nW * 0.14);
        color *= mix(vec3(1.0), vec3(0.72, 0.92, 1.22), nW * 0.80);
        vec3 cb = clamp(color, 0.0, 1.0);
        color = mix(color, cb * cb * (3.0 - 2.0 * cb), nW * 0.30);                 // a little contrast back
        vec3 fogLift = vec3(0.004, 0.010, 0.020) * nW * clamp(NIGHT_FOG, 0.25, 2.0);  // faint blue glow, not a grey veil
        color = fogLift + color * (1.0 - fogLift);
    }
    #elif NIGHT_STYLE == 2
    {
        // Dark rainforest: gloomy desaturated teal-grey canopy, warm rust-brown ground, silvery river highlights
        float nW = todNight(todH);
        float nl = luminance(color);
        // Mute canopy greens toward dark teal-grey
        color = mix(color, vec3(nl) * vec3(0.76, 0.88, 0.92), clamp(foliage * nW * 0.68, 0.0, 1.0));
        // Preserve & nudge warm rust-brown forest floor (moss, needles, ferns)
        float rustW = clamp((color.r - color.b) / max(color.r, 1e-4), 0.0, 1.0)
                    * smoothstep(0.02, 0.28, nl) * (1.0 - smoothstep(0.42, 0.76, nl));
        color *= mix(vec3(1.0), vec3(1.18, 0.95, 0.82), clamp(rustW * nW * 0.65, 0.0, 1.0));
        // Silvery-white water/specular highlights
        float silverHi = smoothstep(0.48, 0.84, nl);
        color = mix(color, vec3(nl) * vec3(0.95, 0.98, 1.02), silverHi * nW * 0.50);
        // Heavy gloom darkening
        color *= mix(1.0, 0.84, nW);
    }
    #endif
    color = max(color, 0.0);
#endif

#ifdef VIGNETTE
    vec2 v = uv - 0.5;
    color *= 1.0 - dot(v, v) * 0.38;
#endif
    return clamp(color, 0.0, 1.0);

#elif LOOK_STYLE == 2
    // Clear Winter (LOOK_STYLE == 2): crisp sunny post-snowfall, clean bright whites,
    // cobalt-blue shadows, rich Christmas reds
    float evergreenDepth = (EVERGREEN_DEPTH < 0.0) ? 0.35 : EVERGREEN_DEPTH;
    float shadowCoolness = (SHADOW_COOLNESS < 0.0) ? 0.85 : SHADOW_COOLNESS;
    float blackLift      = (BLACK_LIFT      < 0.0) ? 0.0  : BLACK_LIFT;
    float warmPop        = (WARM_ACCENT_POP < 0.0) ? 1.15 : WARM_ACCENT_POP;
    float moodContrast   = (MOOD_CONTRAST   < 0.0) ? 0.25 : MOOD_CONTRAST;

    // 1) Gentle conifer richness so pines stand out against snow
    float greenness = clamp((color.g - max(color.r, color.b)) / max(color.g, 1e-4), 0.0, 1.0);
    color = mix(color, color * vec3(0.74, 0.88, 0.86), clamp(greenness * 0.55 * evergreenDepth, 0.0, 1.0));

    // 2) Crisp blue shadows while keeping bright neutral snow pure white
    float wl = luminance(color);
    float shadowW = 1.0 - smoothstep(0.08, 0.52, wl);
    color *= mix(vec3(1.0), vec3(0.86, 0.95, 1.12), shadowW * clamp(shadowCoolness, 0.0, 1.5));

    float snowW = smoothstep(0.60, 0.92, wl);
    float chroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
    float neutralSnow = snowW * (1.0 - smoothstep(0.05, 0.22, chroma));
    color = mix(color, vec3(wl) * 1.03, neutralSnow * 0.35);

    // 3) Richer Christmas reds and warm festive lights
    float redness = clamp((color.r - max(color.g, color.b)) / max(color.r, 1e-4), 0.0, 1.0);
    color = mix(color, color * vec3(1.16, 0.91, 0.90), clamp(redness * 0.70 * warmPop, 0.0, 1.0));

    // 4) Crisp contrast + optional black lift
    vec3 c = clamp(color, 0.0, 1.0);
    vec3 sCurve = c * c * (3.0 - 2.0 * c);
    color = mix(color, sCurve, clamp(moodContrast, 0.0, 0.85));
    vec3 liftCol = vec3(0.92, 0.96, 1.04) * clamp(blackLift, 0.0, 0.08);
    color = liftCol + color * (1.0 - liftCol);

    // Warmth relative to default 1.0 and clean winter saturation
    color = max(color * mix(vec3(1.0), vec3(1.025, 1.0, 0.96), WARMTH - 1.0), 0.0);
    float l = luminance(color);
    color = max(mix(vec3(l), color, SATURATION * 1.06), 0.0);

#if !defined NETHER && !defined END && (SUNRISE_STYLE != 0 || MORNING_STYLE != 0 || MIDDAY_STYLE != 0 || AFTERNOON_STYLE != 0 || SUNSET_STYLE != 0 || NIGHT_STYLE != 0)
    float todH = getSunHeight();
    #if SUNRISE_STYLE == 1
    {
        // Frosty pink dawn: delicate pale pink kiss on neutral snow + icy cobalt shadows
        float rW = todSunrise(todH) * SUNSET_INTENSITY;
        float rLum = luminance(color);
        float rChroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
        float snowPeak = smoothstep(0.48, 0.88, rLum) * (1.0 - smoothstep(0.10, 0.34, rChroma));
        float rSh = 1.0 - smoothstep(0.05, 0.40, rLum);
        color *= mix(vec3(1.0), vec3(1.14, 0.92, 0.97), clamp(snowPeak * rW * ALPENGLOW * 0.68, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.88, 0.94, 1.12), clamp(rSh * rW * 0.50, 0.0, 1.0));
    }
    #elif SUNRISE_STYLE == 2
    {
        // Deep orange cold dawn: vivid copper-orange highlights against frigid steel-blue shadows
        float rW = todSunrise(todH) * SUNSET_INTENSITY;
        float rLum = luminance(color);
        float rHi = smoothstep(0.40, 0.86, rLum);
        float rSh = 1.0 - smoothstep(0.05, 0.38, rLum);
        color *= mix(vec3(1.0), vec3(1.18, 0.96, 0.72), clamp(rHi * rW * 0.66, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.84, 0.92, 1.14), clamp(rSh * rW * 0.56, 0.0, 1.0));
    }
    #endif
    #if MORNING_STYLE == 1
    {
        // Diamond-dust sparkle: crisp glistening snow highlights + clean glacial clarity
        float mW = todMorning(todH) * clamp(DAY_INTENSITY, 0.5, 1.5) * (1.0 - rainStrength * 0.65);
        float mLum = luminance(color);
        float mChroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
        float sparkle = smoothstep(0.68, 0.96, mLum) * (1.0 - smoothstep(0.06, 0.24, mChroma));
        color += vec3(0.065, 0.070, 0.080) * sparkle * clamp(mW, 0.0, 1.5);
        vec3 mc = clamp(color, 0.0, 1.0);
        color = mix(color, mc * mc * (3.0 - 2.0 * mc), clamp(mW * 0.14, 0.0, 0.28));
    }
    #elif MORNING_STYLE == 2
    {
        // Pale blue cold: crisp frigid blue cast across shadows and mids
        float mW = todMorning(todH) * clamp(DAY_INTENSITY, 0.5, 1.5);
        float mLum = luminance(color);
        float mSh = 1.0 - smoothstep(0.06, 0.54, mLum);
        color *= mix(vec3(1.0), vec3(0.88, 0.96, 1.12), clamp(mSh * mW * 0.54, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.95, 0.98, 1.05), clamp(mW * 0.35, 0.0, 0.60));
    }
    #endif
    #if MIDDAY_STYLE == 1
    {
        // Bluebird powder day: dazzling pure snow whites, vivid cobalt shadows, punchy contrast
        float dW = todMidday(todH) * clamp(DAY_INTENSITY, 0.5, 1.5) * (1.0 - rainStrength * 0.70);
        float dLum = luminance(color);
        float dChroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
        float dSnow = smoothstep(0.56, 0.92, dLum) * (1.0 - smoothstep(0.06, 0.24, dChroma));
        float dSh = 1.0 - smoothstep(0.06, 0.46, dLum);
        color *= mix(vec3(1.0), vec3(0.84, 0.93, 1.16), clamp(dSh * dW * 0.55, 0.0, 1.0));
        color = mix(color, vec3(dLum) * 1.07, clamp(dSnow * dW * 0.42, 0.0, 0.70));
        vec3 dc = clamp(color, 0.0, 1.0);
        color = mix(color, dc * dc * (3.0 - 2.0 * dc), clamp(dW * 0.20, 0.0, 0.36));
    }
    #elif MIDDAY_STYLE == 2
    {
        // Ice-crystal haze: bright milky frost lift, low contrast, sparkly snow highlights
        float dW = todMidday(todH) * clamp(DAY_INTENSITY, 0.5, 1.5);
        float dLum = luminance(color);
        float dChroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
        float sparkle = smoothstep(0.72, 0.96, dLum) * (1.0 - smoothstep(0.06, 0.24, dChroma));
        color = mix(color, vec3(dLum) * vec3(0.96, 0.98, 1.04), clamp(dW * 0.22, 0.0, 0.40));
        vec3 iceLift = vec3(0.022, 0.025, 0.032) * clamp(dW, 0.0, 1.5);
        color = iceLift + color * (1.0 - iceLift);
        color += vec3(0.055, 0.060, 0.070) * sparkle * clamp(dW, 0.0, 1.5);
    }
    #endif
    #if AFTERNOON_STYLE == 1
    {
        // Long blue shadows, golden snow: warm golden snow highlights vs deep cobalt shadows
        float aW = todAfternoon(todH) * clamp(DAY_INTENSITY, 0.5, 1.5) * (1.0 - rainStrength * 0.65);
        float aLum = luminance(color);
        float aHi = smoothstep(0.42, 0.88, aLum);
        float aSh = 1.0 - smoothstep(0.06, 0.44, aLum);
        color *= mix(vec3(1.0), vec3(1.13, 1.02, 0.82), clamp(aHi * aW * 0.60, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.82, 0.92, 1.18), clamp(aSh * aW * 0.58, 0.0, 1.0));
    }
    #elif AFTERNOON_STYLE == 2
    {
        // Flat white: bright low-contrast winter whiteout lift
        float aW = todAfternoon(todH) * clamp(DAY_INTENSITY, 0.5, 1.5);
        float aLum = luminance(color);
        color = mix(color, vec3(aLum) * vec3(0.98, 0.99, 1.02), clamp(aW * 0.30, 0.0, 0.48));
        vec3 whiteLift = vec3(0.026, 0.028, 0.032) * clamp(aW, 0.0, 1.5);
        color = whiteLift + color * (1.0 - whiteLift);
        color = color / (1.0 + 0.10 * clamp(aW, 0.0, 1.5) * max(color - 0.66, 0.0));
    }
    #endif
    #if SUNSET_STYLE == 1
    {
        // Alpine alpenglow: crisp pink-coral on neutral snow peaks, clean cobalt shadows
        float sW = todSunset(todH) * SUNSET_INTENSITY;
        float sLum = luminance(color);
        float sChroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
        float snowPeak = smoothstep(0.50, 0.90, sLum) * (1.0 - smoothstep(0.10, 0.34, sChroma));
        color *= mix(vec3(1.0), vec3(1.18, 0.86, 0.91), clamp(snowPeak * sW * ALPENGLOW * 0.75, 0.0, 1.0));
    }
    #elif SUNSET_STYLE == 2
    {
        // Winter gold: crisp golden highlight sheen against icy blue shadows
        float sW = todSunset(todH) * SUNSET_INTENSITY;
        float sLum = luminance(color);
        float goldHi = smoothstep(0.42, 0.88, sLum);
        color *= mix(vec3(1.0), vec3(1.14, 1.03, 0.82), clamp(goldHi * sW * 0.62, 0.0, 1.0));
    }
    #endif
    #if NIGHT_STYLE == 1
    {
        // Moonlit snow blue: luminous cobalt-silver moonlight
        float nW = todNight(todH);
        float nl = luminance(color);
        float snowHi = smoothstep(0.45, 0.86, nl);
        color *= mix(vec3(1.0), vec3(0.86, 0.95, 1.15), nW * 0.55);
        color = mix(color, vec3(nl) * vec3(0.92, 0.97, 1.08), snowHi * nW * 0.35);
    }
    #elif NIGHT_STYLE == 2
    {
        // Arctic starlight: deep crisp polar night with bright white-silver snow
        float nW = todNight(todH);
        float nl = luminance(color);
        float shW = 1.0 - smoothstep(0.05, 0.42, nl);
        color *= mix(vec3(1.0), vec3(0.84, 0.90, 1.06), shW * nW * 0.55);
    }
    #endif
    color = max(color, 0.0);
#endif

#ifdef VIGNETTE
    vec2 v = uv - 0.5;
    color *= 1.0 - dot(v, v) * 0.25;
#endif
    return clamp(color, 0.0, 1.0);
#else
    // Dreamy (LOOK_STYLE == 3): gentle lifted pastel, warm sunlit white-pink snow,
    // cool lavender-blue shadows, pleasant purple interior toe, filmic highlight rolloff
    float evergreenDepth = (EVERGREEN_DEPTH < 0.0) ? 0.25  : EVERGREEN_DEPTH;
    float shadowCoolness = (SHADOW_COOLNESS < 0.0) ? 0.85  : SHADOW_COOLNESS;
    float blackLift      = (BLACK_LIFT      < 0.0) ? 0.018 : BLACK_LIFT;
    float warmPop        = (WARM_ACCENT_POP < 0.0) ? 0.70  : WARM_ACCENT_POP;
    float moodContrast   = (MOOD_CONTRAST   < 0.0) ? 0.14  : MOOD_CONTRAST;
    float pastel         = clamp(PASTEL_AMOUNT, 0.0, 1.5);

    // 1) Gentle conifer cooling so spruce/birch harmonises with lavender snow
    float greenness = clamp((color.g - max(color.r, color.b)) / max(color.g, 1e-4), 0.0, 1.0);
    color = mix(color, color * vec3(0.80, 0.91, 0.92), clamp(greenness * 0.45 * evergreenDepth, 0.0, 1.0));

    // 2) Warm-cool split: lavender-blue shadows, soft white-pink kiss on sunlit snow/highlights
    float wl      = luminance(color);
    float shadowW = 1.0 - smoothstep(0.04, 0.48, wl);
    float hiW     = smoothstep(0.54, 0.92, wl);
    float chroma  = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
    float neutralHi = hiW * (1.0 - smoothstep(0.08, 0.30, chroma));

    vec3 lavShadow = mix(vec3(1.0), vec3(0.95, 0.92, 1.10), shadowW * clamp(shadowCoolness * 0.85, 0.0, 1.35));
    vec3 pinkSnow  = mix(vec3(1.0), vec3(1.045, 0.985, 1.015), neutralHi * clamp(pastel * 0.75, 0.0, 1.0) * (1.0 - rainStrength * 0.7));
    color = max(color * lavShadow * pinkSnow, 0.0);

    // 3) Gentle warm-accent preservation + moderate pastel saturation (desaturates smoothly in snow/overcast)
    float warmHue = clamp((color.r - color.b) / max(color.r, 1e-4), 0.0, 1.0)
                  * smoothstep(0.02, 0.18, color.r - color.g * 0.55);
    color *= mix(vec3(1.0), vec3(1.07, 1.01, 0.95), clamp(warmHue * 0.45 * warmPop, 0.0, 1.0));

    float l0 = luminance(color);
    float weatherDesat = mix(1.0, 0.74, rainStrength);
    float effSat = SATURATION * mix(0.98, 0.93, clamp(pastel * 0.65, 0.0, 1.0)) * weatherDesat;
    color = max(mix(vec3(l0), color, effSat), 0.0);

    // 4) Gentle S-curve + smooth filmic highlight rolloff (creamy, never harsh)
    vec3 c = clamp(color, 0.0, 1.0);
    vec3 sCurve = c * c * (3.0 - 2.0 * c);
    color = mix(color, sCurve, clamp(moodContrast, 0.0, 0.65));
    color = color / (1.0 + 0.14 * max(color - 0.72, 0.0));

    // 5) Lifted cool-purple toe so interiors and undersides stay pleasant lavender, not black
    vec3 liftTint = mix(vec3(0.92, 0.90, 1.06), vec3(0.96, 0.88, 1.12), clamp(pastel * 0.70, 0.0, 1.0));
    vec3 liftCol  = liftTint * clamp(blackLift, 0.0, 0.08);
    color = liftCol + color * (1.0 - liftCol);

    // Subtle pastel overcast grey-lavender veil during snow/rain
    vec3 snowVeil = vec3(0.016, 0.015, 0.024) * rainStrength;
    color = snowVeil + color * (1.0 - snowVeil);

    // Respect user WARMTH adjustments relative to default 1.0
    color = max(color * mix(vec3(1.0), vec3(1.025, 1.0, 0.96), WARMTH - 1.0), 0.0);

#if !defined NETHER && !defined END && (SUNRISE_STYLE != 0 || MORNING_STYLE != 0 || MIDDAY_STYLE != 0 || AFTERNOON_STYLE != 0 || SUNSET_STYLE != 0 || NIGHT_STYLE != 0)
    float todH = getSunHeight();
    #if SUNRISE_STYLE == 1
    {
        // Peach-lilac dawn: soft peach highlights + pastel lilac shadows
        float rW = todSunrise(todH) * SUNSET_INTENSITY;
        float rLum = luminance(color);
        float rHi = smoothstep(0.40, 0.86, rLum);
        float rSh = 1.0 - smoothstep(0.04, 0.38, rLum);
        color *= mix(vec3(1.0), vec3(1.10, 0.98, 0.90), clamp(rHi * rW * 0.56, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.95, 0.92, 1.10), clamp(rSh * rW * 0.54, 0.0, 1.0));
    }
    #elif SUNRISE_STYLE == 2
    {
        // Rose-gold dawn: glowing rose-gold highlights + warm blush-lavender shadow toe
        float rW = todSunrise(todH) * SUNSET_INTENSITY;
        float rLum = luminance(color);
        float rHi = smoothstep(0.36, 0.84, rLum);
        float rSh = 1.0 - smoothstep(0.04, 0.36, rLum);
        color *= mix(vec3(1.0), vec3(1.13, 0.97, 0.86), clamp(rHi * rW * 0.62, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.98, 0.92, 1.04), clamp(rSh * rW * 0.46, 0.0, 1.0));
    }
    #endif
    #if MORNING_STYLE == 1
    {
        // Soft mint-blue: fresh pastel mint-aqua shadow lift + clean airy highlights
        float mW = todMorning(todH) * clamp(DAY_INTENSITY, 0.5, 1.5) * (1.0 - rainStrength * 0.60);
        float mLum = luminance(color);
        float mSh = 1.0 - smoothstep(0.04, 0.44, mLum);
        color *= mix(vec3(1.0), vec3(0.92, 1.03, 1.06), clamp(mSh * mW * 0.48, 0.0, 1.0));
        vec3 mintLift = vec3(0.008, 0.014, 0.016) * clamp(mW, 0.0, 1.5);
        color = mintLift + color * (1.0 - mintLift);
    }
    #elif MORNING_STYLE == 2
    {
        // Dewy haze: luminous pearl-lavender morning mist veil
        float mW = todMorning(todH) * clamp(DAY_INTENSITY, 0.5, 1.5);
        float mLum = luminance(color);
        color = mix(color, vec3(mLum) * vec3(0.98, 0.97, 1.04), clamp(mW * 0.16, 0.0, 0.32));
        vec3 dewLift = vec3(0.016, 0.015, 0.022) * clamp(mW, 0.0, 1.5);
        color = dewLift + color * (1.0 - dewLift);
    }
    #endif
    #if MIDDAY_STYLE == 1
    {
        // Cotton-candy: airy pastel pink-lavender highlight kiss + soft lilac shadow lift
        float dW = todMidday(todH) * clamp(DAY_INTENSITY, 0.5, 1.5) * (1.0 - rainStrength * 0.65);
        float dLum = luminance(color);
        float dHi = smoothstep(0.46, 0.90, dLum);
        float dSh = 1.0 - smoothstep(0.04, 0.42, dLum);
        color *= mix(vec3(1.0), vec3(1.07, 0.96, 1.03), clamp(dHi * dW * 0.55, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.96, 0.94, 1.08), clamp(dSh * dW * 0.48, 0.0, 1.0));
        vec3 candyLift = vec3(0.012, 0.010, 0.018) * clamp(dW, 0.0, 1.5);
        color = candyLift + color * (1.0 - candyLift);
    }
    #elif MIDDAY_STYLE == 2
    {
        // Golden lazy: warm honey highlights, soft peach mid-haze, cozy warm shadows
        float dW = todMidday(todH) * clamp(DAY_INTENSITY, 0.5, 1.5) * (1.0 - rainStrength * 0.70);
        float dLum = luminance(color);
        float dHi = smoothstep(0.32, 0.86, dLum);
        float dSh = 1.0 - smoothstep(0.04, 0.38, dLum);
        color *= mix(vec3(1.0), vec3(1.10, 1.00, 0.85), clamp(dHi * dW * 0.58, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(1.02, 0.96, 0.98), clamp(dSh * dW * 0.42, 0.0, 1.0));
        vec3 peachHaze = vec3(0.018, 0.012, 0.008) * clamp(dW, 0.0, 1.5);
        color = peachHaze + color * (1.0 - peachHaze);
    }
    #endif
    #if AFTERNOON_STYLE == 1
    {
        // Apricot glow: warm glowing apricot highlights + soft lilac shadows
        float aW = todAfternoon(todH) * clamp(DAY_INTENSITY, 0.5, 1.5) * (1.0 - rainStrength * 0.65);
        float aLum = luminance(color);
        float aHi = smoothstep(0.34, 0.84, aLum);
        float aSh = 1.0 - smoothstep(0.04, 0.38, aLum);
        color *= mix(vec3(1.0), vec3(1.12, 0.98, 0.82), clamp(aHi * aW * 0.60, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.97, 0.93, 1.06), clamp(aSh * aW * 0.46, 0.0, 1.0));
        vec3 apricotLift = vec3(0.016, 0.010, 0.006) * clamp(aW, 0.0, 1.5);
        color = apricotLift + color * (1.0 - apricotLift);
    }
    #elif AFTERNOON_STYLE == 2
    {
        // Lavender drift: dreamy pastel violet-lavender atmospheric veil
        float aW = todAfternoon(todH) * clamp(DAY_INTENSITY, 0.5, 1.5);
        float aLum = luminance(color);
        color = mix(color, vec3(aLum) * vec3(0.98, 0.93, 1.08), clamp(aW * 0.22, 0.0, 0.40));
        vec3 lavLift = vec3(0.014, 0.011, 0.024) * clamp(aW, 0.0, 1.5);
        color = lavLift + color * (1.0 - lavLift);
    }
    #endif
    #if SUNSET_STYLE == 1
    {
        // Dreamy cotton-candy alpenglow: pastel pink highlights + soft lavender shadows
        float sW = todSunset(todH) * SUNSET_INTENSITY;
        float sLum = luminance(color);
        float sChroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
        float snowPeak = smoothstep(0.44, 0.88, sLum) * (1.0 - smoothstep(0.14, 0.44, sChroma));
        float shLow = 1.0 - smoothstep(0.04, 0.38, sLum);
        color *= mix(vec3(1.0), vec3(1.14, 0.90, 0.98), clamp(snowPeak * sW * ALPENGLOW * 0.72, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.93, 0.91, 1.08), clamp(shLow * sW * 0.55, 0.0, 1.0));
    }
    #elif SUNSET_STYLE == 2
    {
        // Dreamy honey peach golden hour: warm peach-cream highlights + lilac shadow split
        float sW = todSunset(todH) * SUNSET_INTENSITY;
        float sLum = luminance(color);
        float peachHi = smoothstep(0.34, 0.84, sLum);
        float lilacSh = 1.0 - smoothstep(0.04, 0.36, sLum);
        color *= mix(vec3(1.0), vec3(1.12, 1.01, 0.86), clamp(peachHi * sW * 0.62, 0.0, 1.0));
        color *= mix(vec3(1.0), vec3(0.95, 0.92, 1.04), clamp(lilacSh * sW * 0.48, 0.0, 1.0));
    }
    #endif
    #if NIGHT_STYLE == 1
    {
        // Dreamy lavender mist night: luminous soft periwinkle-lavender haze lift
        float nW = todNight(todH);
        float nl = luminance(color);
        color = mix(color, vec3(nl) * vec3(0.92, 0.92, 1.10), nW * 0.24);
        vec3 mistLift = vec3(0.012, 0.012, 0.026) * nW * clamp(NIGHT_FOG, 0.25, 2.0);
        color = mistLift + color * (1.0 - mistLift);
    }
    #elif NIGHT_STYLE == 2
    {
        // Dreamy starry violet night: deeper twilight contrast with soft violet shadows
        float nW = todNight(todH);
        color *= mix(vec3(1.0), vec3(0.94, 0.92, 1.08), nW * 0.42);
        vec3 nc = clamp(color, 0.0, 1.0);
        color = mix(color, nc * nc * (3.0 - 2.0 * nc), nW * 0.16);
    }
    #endif
    color = max(color, 0.0);
#endif

#ifdef VIGNETTE
    vec2 v = uv - 0.5;
    color *= 1.0 - dot(v, v) * 0.22;
#endif
    return clamp(color, 0.0, 1.0);
#endif
}

void main() {
    vec3 color = texture(colortex0, texcoord).rgb;

    // soft, wide bloom
#ifdef BLOOM
    // two wide levels instead of three: the same soft glow for 2/3 of the work
    vec3 bloom = sampleBloomLevel(3.5) * 0.60
               + sampleBloomLevel(5.5) * 0.40;
    color = mix(color, bloom, 0.07 * BLOOM_STRENGTH);
#endif

    // brighten things up a bit in caves and at night so it's not pitch black
    float eyeSky = eyeBrightnessSmooth.y / 240.0;
    float exposure = mix(1.9, 1.0, eyeSky);
#if !defined NETHER && !defined END
    exposure *= mix(1.0, 1.7, getNightFactor(getSunHeight()) * eyeSky);
#endif
    color *= exposure * EXPOSURE * 0.80;

    // per-channel ACES oversaturates bright yellows; blend with a version that keeps the hue
    vec3 perChannel = acesFilmic(color);
    float lum = luminance(color);
    vec3 huePreserving = color * (luminance(acesFilmic(vec3(lum))) / max(lum, 1e-5));
    color = mix(perChannel, min(huePreserving, 1.0), 0.45);

    color = applyLook(color, texcoord);   // grading per Look Style (Classic = the original grade)

    color = pow(clamp(color, 0.0, 1.0), vec3(1.0 / 2.2));
    color += (hash12(gl_FragCoord.xy + float(frameCounter % 64)) - 0.5) / 255.0;

    outColor = vec4(color, 1.0);
}

#endif

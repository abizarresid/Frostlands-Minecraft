// Time-of-day, sky, moon, stars and light colours. All colours are linear HDR.

uniform int moonPhase; // 0 = full, 1..3 = waning, 4 = new, 5..7 = waxing

float getSunHeight() {
    return dot(normalize(sunPosition), normalize(upPosition));
}

// 1 around sunrise/sunset, 0 at noon and midnight
float getSunsetFactor(float h) {
    float x = (h - 0.05) * 4.0;  // a long golden hour
    return exp(-x * x);
}

float getDayFactor(float h)   { return smoothstep(-0.08, 0.28, h); }
float getNightFactor(float h) { return 1.0 - smoothstep(-0.22, 0.02, h); }
// 1 in full daytime, 0 around sunrise/sunset/night
float getFullDayFactor(float h) {
    return clamp(smoothstep(0.15, 0.45, h) * (1.0 - getSunsetFactor(h)), 0.0, 1.0);
}

// Smooth, periodic morning-side vs evening-side split (no seam at 24000 -> 0).
// 1.0 around sunrise (t = 0), 0.0 around sunset (t = 12000), 0.5 at noon & midnight.
float todMorningSide() {
    float t = mod(float(worldTime), 24000.0);
    return smoothstep(-0.25, 0.25, cos(t * 0.00026179939)); // 2*pi / 24000
}

float todEveningSide() {
    return 1.0 - todMorningSide();
}

// Daytime envelope complementing sunrise/sunset/night so all 6 weights sum to ~1
float todDayEnvelope(float h) {
    return clamp(smoothstep(0.02, 0.25, h) * (1.0 - getSunsetFactor(h)), 0.0, 1.0);
}

// Smooth, overlapping time-of-day weights (with h already computed)
float todSunrise(float h) { return getSunsetFactor(h) * todMorningSide(); }
float todSunset(float h)  { return getSunsetFactor(h) * todEveningSide(); }
float todNight(float h)   { return getNightFactor(h); }

float todMorning(float h) {
    float t = mod(float(worldTime), 24000.0);
    float mask = smoothstep(300.0, 1300.0, t) * (1.0 - smoothstep(3500.0, 4800.0, t));
    return todDayEnvelope(h) * mask;
}

float todMidday(float h) {
    float t = mod(float(worldTime), 24000.0);
    float mask = smoothstep(3500.0, 4800.0, t) * (1.0 - smoothstep(7200.0, 8500.0, t));
    return todDayEnvelope(h) * mask;
}

float todAfternoon(float h) {
    float t = mod(float(worldTime), 24000.0);
    float mask = smoothstep(7200.0, 8500.0, t) * (1.0 - smoothstep(10800.0, 12000.0, t));
    return todDayEnvelope(h) * mask;
}

// Convenience zero-argument overloads
float todSunrise()   { return todSunrise(getSunHeight()); }
float todMorning()   { return todMorning(getSunHeight()); }
float todMidday()    { return todMidday(getSunHeight()); }
float todAfternoon() { return todAfternoon(getSunHeight()); }
float todSunset()    { return todSunset(getSunHeight()); }
float todNight()     { return todNight(getSunHeight()); }

// 1.0 at full moon (moonPhase == 0), 0.0 at new moon (moonPhase == 4)
float getMoonPhaseIllum() {
    float phi = float(moonPhase) * 0.78539816; // 2*pi / 8
    return 0.5 + 0.5 * cos(phi);
}

// Colour of direct light from the sun (or moon once the sun has set)
vec3 getDirectLightColor() {
#if defined NETHER || defined END
    return vec3(0.0);
#else
    float h = getSunHeight();
    float day = smoothstep(0.0, 0.40, h);
    float si = 1.0 + (SUNSET_INTENSITY - 1.0) * 0.45; // exact 1.0 at default

    // Base low-sun colour per LOOK_STYLE (exact default when SUNRISE_STYLE == 0 && SUNSET_STYLE == 0)
#if LOOK_STYLE == 3
    // Dreamy: warm creamy peach-pink low sun so snow glows soft white-pink
    vec3 sunLowBase = vec3(1.0, 0.68, 0.54) * 1.72;
#else
    vec3 sunLowBase = vec3(1.0, 0.47, 0.18) * 1.6;
#endif

#if SUNRISE_STYLE == 0 && SUNSET_STYLE == 0
    vec3 sunLow = sunLowBase * si;
#else
    vec3 sunLowRise = sunLowBase;
    vec3 sunLowSet  = sunLowBase;

    // Morning-side (sunrise) low-sun colour
    #if LOOK_STYLE == 1
        #if SUNRISE_STYLE == 1
        // PNW Moody - Fog-bound pink seam: dim rosy-pink light peeking under grey fog
        sunLowRise = vec3(1.0, 0.68, 0.72) * 1.15;
        #elif SUNRISE_STYLE == 2
        // PNW Moody - Mt. Rainier dawn alpenglow: crisp cool-rose light on high peaks
        sunLowRise = mix(vec3(1.0, 0.68, 0.62), vec3(1.0, 0.42, 0.52), clamp(ALPENGLOW * 0.75, 0.0, 1.0)) * (1.68 + 0.24 * ALPENGLOW);
        #endif
    #elif LOOK_STYLE == 2
        #if SUNRISE_STYLE == 1
        // Clear Winter - Frosty pink dawn: delicate crisp pale rose-pink low sun
        sunLowRise = mix(vec3(1.0, 0.74, 0.72), vec3(1.0, 0.52, 0.60), clamp(ALPENGLOW * 0.65, 0.0, 1.0)) * (1.68 + 0.18 * ALPENGLOW);
        #elif SUNRISE_STYLE == 2
        // Clear Winter - Deep orange cold dawn: vivid copper-orange arctic low sun
        sunLowRise = vec3(1.0, 0.46, 0.14) * 1.98;
        #endif
    #elif LOOK_STYLE == 3
        #if SUNRISE_STYLE == 1
        // Dreamy - Peach-lilac dawn: soft pastel peach-cream low sun
        sunLowRise = vec3(1.0, 0.74, 0.64) * 1.74;
        #elif SUNRISE_STYLE == 2
        // Dreamy - Rose-gold dawn: luminous warm rose-gold low sun
        sunLowRise = vec3(1.0, 0.68, 0.50) * 1.90;
        #endif
    #else
        #if SUNRISE_STYLE == 1
        // Hearth Classic - Rosy pastel dawn: soft blush-peach low sun
        sunLowRise = vec3(1.0, 0.68, 0.62) * 1.62;
        #elif SUNRISE_STYLE == 2
        // Hearth Classic - Golden clear dawn: crisp pale-gold low sun
        sunLowRise = vec3(1.0, 0.66, 0.28) * 1.92;
        #endif
    #endif

    // Evening-side (sunset) low-sun colour
    #if LOOK_STYLE == 1
        #if SUNSET_STYLE == 1
        // PNW Moody - Mt. Rainier alpenglow: hot pink-coral light on high snow peaks
        sunLowSet = mix(vec3(1.0, 0.62, 0.54), vec3(1.0, 0.36, 0.44), clamp(ALPENGLOW * 0.75, 0.0, 1.0)) * (1.70 + 0.25 * ALPENGLOW);
        #elif SUNSET_STYLE == 2
        // PNW Moody - Cascades golden hour: rich backlit amber-gold
        sunLowSet = vec3(1.0, 0.58, 0.16) * 2.05;
        #endif
    #elif LOOK_STYLE == 2
        #if SUNSET_STYLE == 1
        // Clear Winter - Alpine alpenglow: crisp pink-coral on snowy peaks
        sunLowSet = mix(vec3(1.0, 0.66, 0.58), vec3(1.0, 0.40, 0.48), clamp(ALPENGLOW * 0.75, 0.0, 1.0)) * (1.75 + 0.25 * ALPENGLOW);
        #elif SUNSET_STYLE == 2
        // Clear Winter - Winter gold: crisp low arctic gold
        sunLowSet = vec3(1.0, 0.64, 0.24) * 1.90;
        #endif
    #elif LOOK_STYLE == 3
        #if SUNSET_STYLE == 1
        // Dreamy - Cotton-candy rose alpenglow
        sunLowSet = mix(vec3(1.0, 0.70, 0.66), vec3(1.0, 0.52, 0.62), clamp(ALPENGLOW * 0.70, 0.0, 1.0)) * (1.75 + 0.20 * ALPENGLOW);
        #elif SUNSET_STYLE == 2
        // Dreamy - Honey peach golden hour
        sunLowSet = vec3(1.0, 0.70, 0.38) * 1.88;
        #endif
    #else
        #if SUNSET_STYLE == 1
        // Hearth Classic - Rose alpenglow
        sunLowSet = mix(vec3(1.0, 0.60, 0.48), vec3(1.0, 0.42, 0.46), clamp(ALPENGLOW * 0.70, 0.0, 1.0)) * (1.60 + 0.20 * ALPENGLOW);
        #elif SUNSET_STYLE == 2
        // Hearth Classic - Amber golden hour
        sunLowSet = vec3(1.0, 0.56, 0.18) * 1.95;
        #endif
    #endif

    vec3 sunLow = mix(sunLowSet, sunLowRise, todMorningSide()) * si;
#endif

#if LOOK_STYLE == 3
    vec3 sunCol = mix(sunLow, vec3(1.0, 0.94, 0.87) * 2.25, day);
#else
    vec3 sunCol = mix(sunLow, vec3(1.0, 0.93, 0.84) * 2.4, day);
#endif

#if MORNING_STYLE != 0 || MIDDAY_STYLE != 0 || AFTERNOON_STYLE != 0
    // Daytime direct sun overrides per LOOK_STYLE across morning / midday / afternoon
    float dayInt = 0.67 * clamp(DAY_INTENSITY, 0.5, 1.5);
    float mW = 0.0, dW = 0.0, aW = 0.0;
    vec3 mSunCol = sunCol, dSunCol = sunCol, aSunCol = sunCol;

    #if MORNING_STYLE != 0
    mW = todMorning(h);
        #if LOOK_STYLE == 1
            #if MORNING_STYLE == 1
            // PNW Moody - Burning-off marine layer: pale warm sun breaking through mist
            mSunCol = vec3(1.00, 0.93, 0.82) * 2.15;
            #elif MORNING_STYLE == 2
            // PNW Moody - Drizzle grey: dim heavily diffused cool-slate light
            mSunCol = vec3(0.86, 0.92, 0.97) * 0.72;
            #endif
        #elif LOOK_STYLE == 2
            #if MORNING_STYLE == 1
            // Clear Winter - Diamond-dust sparkle: crisp dazzling icy-white morning sun
            mSunCol = vec3(1.00, 0.98, 0.96) * 2.85;
            #elif MORNING_STYLE == 2
            // Clear Winter - Pale blue cold: crisp frigid cool-white morning sun
            mSunCol = vec3(0.92, 0.96, 1.02) * 2.20;
            #endif
        #elif LOOK_STYLE == 3
            #if MORNING_STYLE == 1
            // Dreamy - Soft mint-blue: airy cool-cream morning sunlight
            mSunCol = vec3(0.96, 0.99, 0.97) * 2.18;
            #elif MORNING_STYLE == 2
            // Dreamy - Dewy haze: soft milky luminous morning sun
            mSunCol = vec3(1.00, 0.96, 0.94) * 1.75;
            #endif
        #else
            #if MORNING_STYLE == 1
            // Hearth Classic - Fresh cool crisp: bright clean cool-tinted morning sun
            mSunCol = vec3(0.97, 0.98, 1.00) * 2.65;
            #elif MORNING_STYLE == 2
            // Hearth Classic - Misty soft: diffused pale warm morning light
            mSunCol = vec3(1.00, 0.94, 0.88) * 1.65;
            #endif
        #endif
    #endif

    #if MIDDAY_STYLE != 0
    dW = todMidday(h);
        #if LOOK_STYLE == 1
            #if MIDDAY_STYLE == 1
            // PNW Moody - Sun breaks after rain: punchy warm-white shafts through dark clouds
            dSunCol = vec3(1.00, 0.92, 0.80) * 2.95;
            #elif MIDDAY_STYLE == 2
            // PNW Moody - Marine-layer grey: heavily diffused pearly light, very soft shadows
            dSunCol = vec3(0.90, 0.94, 0.98) * 0.85;
            #endif
        #elif LOOK_STYLE == 2
            #if MIDDAY_STYLE == 1
            // Clear Winter - Bluebird powder day: intense crisp alpine sun
            dSunCol = vec3(1.00, 0.97, 0.93) * 3.05;
            #elif MIDDAY_STYLE == 2
            // Clear Winter - Ice-crystal haze: bright milky diffused sun
            dSunCol = vec3(0.98, 0.97, 1.00) * 1.55;
            #endif
        #elif LOOK_STYLE == 3
            #if MIDDAY_STYLE == 1
            // Dreamy - Cotton-candy: soft warm creamy-rose sun
            dSunCol = vec3(1.00, 0.91, 0.88) * 2.10;
            #elif MIDDAY_STYLE == 2
            // Dreamy - Golden lazy: warm honey sunlight
            dSunCol = vec3(1.00, 0.84, 0.62) * 2.45;
            #endif
        #else
            #if MIDDAY_STYLE == 1
            // Hearth Classic - Crisp clear: strong clean sunlight, sharp shadows
            dSunCol = vec3(1.00, 0.96, 0.90) * 2.85;
            #elif MIDDAY_STYLE == 2
            // Hearth Classic - Soft overcast: diffused silvery sun, gentle shadows
            dSunCol = vec3(0.95, 0.96, 1.00) * 1.15;
            #endif
        #endif
    #endif

    #if AFTERNOON_STYLE != 0
    aW = todAfternoon(h);
        #if LOOK_STYLE == 1
            #if AFTERNOON_STYLE == 1
            // PNW Moody - Low-angle forest shafts: punchy warm amber raking light
            aSunCol = vec3(1.00, 0.80, 0.50) * 2.85;
            #elif AFTERNOON_STYLE == 2
            // PNW Moody - Squally showers: dim stormy silvery-blue light
            aSunCol = vec3(0.84, 0.90, 0.96) * 0.95;
            #endif
        #elif LOOK_STYLE == 2
            #if AFTERNOON_STYLE == 1
            // Clear Winter - Long blue shadows, golden snow: warm low golden alpine sun
            aSunCol = vec3(1.00, 0.82, 0.52) * 2.75;
            #elif AFTERNOON_STYLE == 2
            // Clear Winter - Flat white: heavily diffused overcast winter light
            aSunCol = vec3(0.96, 0.97, 1.00) * 0.95;
            #endif
        #elif LOOK_STYLE == 3
            #if AFTERNOON_STYLE == 1
            // Dreamy - Apricot glow: warm glowing apricot-peach sun
            aSunCol = vec3(1.00, 0.80, 0.58) * 2.40;
            #elif AFTERNOON_STYLE == 2
            // Dreamy - Lavender drift: soft muted lavender-tinted sun
            aSunCol = vec3(0.98, 0.90, 0.98) * 1.85;
            #endif
        #else
            #if AFTERNOON_STYLE == 1
            // Hearth Classic - Warm golden: rich warm late-afternoon sun
            aSunCol = vec3(1.00, 0.82, 0.56) * 2.60;
            #elif AFTERNOON_STYLE == 2
            // Hearth Classic - Hazy summer: warm slightly diffused afternoon sun
            aSunCol = vec3(1.00, 0.90, 0.72) * 2.05;
            #endif
        #endif
    #endif

    float wSum = mW + dW + aW;
    if (wSum > 1e-4) {
        vec3 styleSun = (mSunCol * mW + dSunCol * dW + aSunCol * aW) / wSum;
        sunCol = mix(sunCol, styleSun, clamp(wSum * dayInt, 0.0, 1.0));
    }
#endif

    // Moonlight colour per LOOK_STYLE and NIGHT_STYLE
    vec3 moonCol = vec3(0.50, 0.62, 1.0) * 0.11;
#if LOOK_STYLE == 1
    #if NIGHT_STYLE == 1
    // PNW Moody - Blue hour forest fog: soft cold blue-teal moonlight
    moonCol = vec3(0.46, 0.68, 0.96) * 0.13;
    #elif NIGHT_STYLE == 2
    // PNW Moody - Dark rainforest: dim silvery-white sheen (catches river water)
    moonCol = vec3(0.70, 0.77, 0.84) * 0.095;
    #endif
#elif LOOK_STYLE == 2
    #if NIGHT_STYLE == 1
    // Clear Winter - Moonlit snow blue
    moonCol = vec3(0.56, 0.76, 1.05) * 0.15;
    #elif NIGHT_STYLE == 2
    // Clear Winter - Arctic starlight
    moonCol = vec3(0.66, 0.78, 1.00) * 0.11;
    #endif
#elif LOOK_STYLE == 3
    // Dreamy: soft periwinkle-lavender moonlight
    moonCol = vec3(0.66, 0.68, 1.02) * 0.14;
    #if NIGHT_STYLE == 1
    // Dreamy - Lavender mist night
    moonCol = vec3(0.70, 0.72, 1.06) * 0.16;
    #elif NIGHT_STYLE == 2
    // Dreamy - Starry violet night
    moonCol = vec3(0.72, 0.76, 1.02) * 0.125;
    #endif
#else
    #if NIGHT_STYLE == 1
    // Hearth Classic - Moonlit mist
    moonCol = vec3(0.55, 0.70, 1.00) * 0.13;
    #elif NIGHT_STYLE == 2
    // Hearth Classic - Starry clear
    moonCol = vec3(0.60, 0.72, 0.98) * 0.10;
    #endif
#endif

    // Moon phase modulation: full moon = 1.0x (matches original Classic), new moon dimmer & cooler
    float phaseIllum = getMoonPhaseIllum();
    float phaseMul = mix(0.38, 1.0, phaseIllum);
    vec3 phaseTint = mix(vec3(0.76, 0.86, 1.12), vec3(1.0), phaseIllum);
    moonCol *= phaseMul * phaseTint * NIGHT_BRIGHTNESS;

    vec3 col = h > 0.0 ? sunCol : moonCol;
    // fade out around the horizon so the sun/moon swap is invisible
    col *= smoothstep(0.0, 0.07, abs(h));
    col *= 1.0 - rainStrength * 0.9;
    return max(col, 0.0) * SUN_BRIGHTNESS;
#endif
}

// Colour of the light coming from the whole sky (fills in shadows)
vec3 getAmbientColor() {
#if defined NETHER
    return vec3(0.34, 0.20, 0.14) * 0.55 * AMBIENT_BRIGHTNESS;
#elif defined END
    return vec3(0.20, 0.16, 0.30) * 0.6 * AMBIENT_BRIGHTNESS;
#else
    float h = getSunHeight();
#if LOOK_STYLE == 3
    // Dreamy: cool lavender-blue shadow fill so shaded snow & interiors read soft purple, never black
    vec3 dayCol = vec3(0.42, 0.41, 0.62) * 0.68;
#else
    vec3 dayCol = vec3(0.34, 0.42, 0.56) * 0.62;
#endif

#if MORNING_STYLE != 0 || MIDDAY_STYLE != 0 || AFTERNOON_STYLE != 0
    // Daytime ambient shadow fill per LOOK_STYLE across morning / midday / afternoon
    float dayInt = 0.67 * clamp(DAY_INTENSITY, 0.5, 1.5);
    float mW = 0.0, dW = 0.0, aW = 0.0;
    vec3 mDayCol = dayCol, dDayCol = dayCol, aDayCol = dayCol;

    #if MORNING_STYLE != 0
    mW = todMorning(h);
        #if LOOK_STYLE == 1
            #if MORNING_STYLE == 1
            // PNW Moody - Burning-off marine layer: luminous cool-silver mist fill
            mDayCol = vec3(0.42, 0.50, 0.58) * 0.78;
            #elif MORNING_STYLE == 2
            // PNW Moody - Drizzle grey: damp cool blue-grey overcast fill
            mDayCol = vec3(0.44, 0.51, 0.57) * 0.86;
            #endif
        #elif LOOK_STYLE == 2
            #if MORNING_STYLE == 1
            // Clear Winter - Diamond-dust sparkle: crisp pale ice-blue shadow fill
            mDayCol = vec3(0.34, 0.48, 0.72) * 0.66;
            #elif MORNING_STYLE == 2
            // Clear Winter - Pale blue cold: frigid glacial-blue shadow fill
            mDayCol = vec3(0.28, 0.44, 0.72) * 0.62;
            #endif
        #elif LOOK_STYLE == 3
            #if MORNING_STYLE == 1
            // Dreamy - Soft mint-blue: airy pastel aqua-blue shadow fill
            mDayCol = vec3(0.38, 0.52, 0.66) * 0.72;
            #elif MORNING_STYLE == 2
            // Dreamy - Dewy haze: bright milky pearl-lavender fill
            mDayCol = vec3(0.54, 0.52, 0.72) * 0.84;
            #endif
        #else
            #if MORNING_STYLE == 1
            // Hearth Classic - Fresh cool crisp: clean cool morning sky-blue fill
            mDayCol = vec3(0.30, 0.44, 0.66) * 0.58;
            #elif MORNING_STYLE == 2
            // Hearth Classic - Misty soft: airy pale milky-blue fill
            mDayCol = vec3(0.50, 0.55, 0.64) * 0.80;
            #endif
        #endif
    #endif

    #if MIDDAY_STYLE != 0
    dW = todMidday(h);
        #if LOOK_STYLE == 1
            #if MIDDAY_STYLE == 1
            // PNW Moody - Sun breaks after rain: moody blue-grey shadow fill under dark clouds
            dDayCol = vec3(0.22, 0.30, 0.40) * 0.52;
            #elif MIDDAY_STYLE == 2
            // PNW Moody - Marine-layer grey: high, flat pearly cool-silver fill
            dDayCol = vec3(0.50, 0.56, 0.62) * 0.92;
            #endif
        #elif LOOK_STYLE == 2
            #if MIDDAY_STYLE == 1
            // Clear Winter - Bluebird powder day: vivid alpine cobalt shadow fill
            dDayCol = vec3(0.24, 0.38, 0.68) * 0.56;
            #elif MIDDAY_STYLE == 2
            // Clear Winter - Ice-crystal haze: bright milky ice-blue fill, low shadow contrast
            dDayCol = vec3(0.58, 0.64, 0.74) * 0.88;
            #endif
        #elif LOOK_STYLE == 3
            #if MIDDAY_STYLE == 1
            // Dreamy - Cotton-candy: airy pastel lavender-blue fill
            dDayCol = vec3(0.48, 0.45, 0.70) * 0.76;
            #elif MIDDAY_STYLE == 2
            // Dreamy - Golden lazy: warm apricot-lavender shadow fill
            dDayCol = vec3(0.50, 0.44, 0.56) * 0.66;
            #endif
        #else
            #if MIDDAY_STYLE == 1
            // Hearth Classic - Crisp clear: deeper clear sky-blue shadow fill
            dDayCol = vec3(0.28, 0.40, 0.62) * 0.54;
            #elif MIDDAY_STYLE == 2
            // Hearth Classic - Soft overcast: bright even silvery fill
            dDayCol = vec3(0.56, 0.60, 0.66) * 0.88;
            #endif
        #endif
    #endif

    #if AFTERNOON_STYLE != 0
    aW = todAfternoon(h);
        #if LOOK_STYLE == 1
            #if AFTERNOON_STYLE == 1
            // PNW Moody - Low-angle forest shafts: deep cool conifer shadows under warm shafts
            aDayCol = vec3(0.22, 0.30, 0.38) * 0.48;
            #elif AFTERNOON_STYLE == 2
            // PNW Moody - Squally showers: brooding slate-blue storm ambient
            aDayCol = vec3(0.32, 0.40, 0.50) * 0.70;
            #endif
        #elif LOOK_STYLE == 2
            #if AFTERNOON_STYLE == 1
            // Clear Winter - Long blue shadows, golden snow: rich deep cobalt shadow fill
            aDayCol = vec3(0.20, 0.34, 0.68) * 0.54;
            #elif AFTERNOON_STYLE == 2
            // Clear Winter - Flat white: high bright whiteout snow fill
            aDayCol = vec3(0.68, 0.72, 0.78) * 0.96;
            #endif
        #elif LOOK_STYLE == 3
            #if AFTERNOON_STYLE == 1
            // Dreamy - Apricot glow: soft warm lilac-peach shadow fill
            aDayCol = vec3(0.52, 0.44, 0.60) * 0.68;
            #elif AFTERNOON_STYLE == 2
            // Dreamy - Lavender drift: luminous pastel violet-lavender shadow fill
            aDayCol = vec3(0.52, 0.46, 0.76) * 0.78;
            #endif
        #else
            #if AFTERNOON_STYLE == 1
            // Hearth Classic - Warm golden: balanced warm-slate shadow fill
            aDayCol = vec3(0.36, 0.40, 0.52) * 0.58;
            #elif AFTERNOON_STYLE == 2
            // Hearth Classic - Hazy summer: warm creamy hazy ambient fill
            aDayCol = vec3(0.46, 0.50, 0.58) * 0.72;
            #endif
        #endif
    #endif

    float wSum = mW + dW + aW;
    if (wSum > 1e-4) {
        vec3 styleDayCol = (mDayCol * mW + dDayCol * dW + aDayCol * aW) / wSum;
        dayCol = mix(dayCol, styleDayCol, clamp(wSum * dayInt, 0.0, 1.0));
    }
#endif

    // Low-sun ambient (sunrise on morning side, sunset on evening side)
#if LOOK_STYLE == 3
    // Dreamy: luminous pastel lavender-rose shadow fill
    vec3 lowAmbBase = vec3(0.54, 0.44, 0.64) * 0.55;
#else
    vec3 lowAmbBase = vec3(0.55, 0.42, 0.42) * 0.45;
#endif

#if SUNRISE_STYLE == 0 && SUNSET_STYLE == 0
    vec3 sunsetCol = lowAmbBase;
#else
    vec3 riseAmb = lowAmbBase;
    vec3 setAmb  = lowAmbBase;

    #if LOOK_STYLE == 1
        #if SUNRISE_STYLE == 1
        // PNW Moody - Fog-bound pink seam: cool misty grey-blue shadow fill
        riseAmb = vec3(0.34, 0.40, 0.48) * 0.56;
        #elif SUNRISE_STYLE == 2
        // PNW Moody - Mt. Rainier dawn alpenglow: crisp dark slate-blue forest shadows
        riseAmb = vec3(0.22, 0.28, 0.48) * 0.40;
        #endif
    #elif LOOK_STYLE == 2
        #if SUNRISE_STYLE == 1
        // Clear Winter - Frosty pink: crisp frosted periwinkle shadows
        riseAmb = vec3(0.32, 0.38, 0.60) * 0.48;
        #elif SUNRISE_STYLE == 2
        // Clear Winter - Deep orange cold dawn: cold deep steel-blue shadows
        riseAmb = vec3(0.24, 0.34, 0.58) * 0.44;
        #endif
    #elif LOOK_STYLE == 3
        #if SUNRISE_STYLE == 1
        // Dreamy - Peach-lilac dawn: airy lilac-lavender shadow fill
        riseAmb = vec3(0.50, 0.44, 0.68) * 0.56;
        #elif SUNRISE_STYLE == 2
        // Dreamy - Rose-gold dawn: warm blush-lavender shadow fill
        riseAmb = vec3(0.56, 0.44, 0.62) * 0.54;
        #endif
    #else
        #if SUNRISE_STYLE == 1
        // Hearth Classic - Rosy pastel dawn: soft cool-rose shadow fill
        riseAmb = vec3(0.42, 0.38, 0.54) * 0.46;
        #elif SUNRISE_STYLE == 2
        // Hearth Classic - Golden clear dawn: clean cool-blue morning shadows
        riseAmb = vec3(0.36, 0.40, 0.54) * 0.46;
        #endif
    #endif

    #if LOOK_STYLE == 1
        #if SUNSET_STYLE == 1
        // Mt. Rainier alpenglow: cool dark shadow in the forest below while peaks catch pink light
        setAmb = vec3(0.24, 0.28, 0.46) * 0.38;
        #elif SUNSET_STYLE == 2
        // Cascades golden hour: deep warm brown-teal shadow fill
        setAmb = vec3(0.34, 0.30, 0.26) * 0.44;
        #endif
    #elif LOOK_STYLE == 2
        #if SUNSET_STYLE == 1
        // Alpine alpenglow: crisp cobalt shadows under pink peaks
        setAmb = vec3(0.28, 0.34, 0.56) * 0.44;
        #elif SUNSET_STYLE == 2
        // Winter gold: cool slate-blue shadows
        setAmb = vec3(0.36, 0.40, 0.52) * 0.46;
        #endif
    #elif LOOK_STYLE == 3
        #if SUNSET_STYLE == 1
        setAmb = vec3(0.46, 0.40, 0.66) * 0.52;
        #elif SUNSET_STYLE == 2
        setAmb = vec3(0.56, 0.46, 0.56) * 0.54;
        #endif
    #else
        #if SUNSET_STYLE == 1
        setAmb = vec3(0.38, 0.34, 0.48) * 0.42;
        #elif SUNSET_STYLE == 2
        setAmb = vec3(0.48, 0.38, 0.28) * 0.46;
        #endif
    #endif

    vec3 sunsetCol = mix(setAmb, riseAmb, todMorningSide());
#endif

    // Night ambient per LOOK_STYLE and NIGHT_STYLE
    vec3 nightCol = vec3(0.07, 0.09, 0.16) * 0.55;
#if LOOK_STYLE == 1
    #if NIGHT_STYLE == 1
    // Blue hour forest fog: soft luminous blue-teal fill, nothing pure black
    nightCol = vec3(0.10, 0.16, 0.24) * 0.68;
    #elif NIGHT_STYLE == 2
    // Dark rainforest: heavy gloom, desaturated teal-grey
    nightCol = vec3(0.045, 0.058, 0.064) * 0.44;
    #endif
#elif LOOK_STYLE == 2
    #if NIGHT_STYLE == 1
    // Moonlit snow blue: snow bounce feel
    nightCol = vec3(0.11, 0.16, 0.28) * 0.68;
    #elif NIGHT_STYLE == 2
    // Arctic starlight
    nightCol = vec3(0.06, 0.09, 0.17) * 0.50;
    #endif
#elif LOOK_STYLE == 3
    // Dreamy: soft cool violet-blue night fill, never crushed black
    nightCol = vec3(0.11, 0.11, 0.22) * 0.66;
    #if NIGHT_STYLE == 1
    nightCol = vec3(0.14, 0.15, 0.28) * 0.74;
    #elif NIGHT_STYLE == 2
    nightCol = vec3(0.085, 0.095, 0.20) * 0.58;
    #endif
#else
    #if NIGHT_STYLE == 1
    nightCol = vec3(0.09, 0.13, 0.22) * 0.62;
    #elif NIGHT_STYLE == 2
    nightCol = vec3(0.055, 0.075, 0.145) * 0.48;
    #endif
#endif

    float phaseIllum = getMoonPhaseIllum();
    nightCol *= mix(0.84, 1.0, phaseIllum) * NIGHT_BRIGHTNESS;

    vec3 col = mix(sunsetCol, dayCol, getDayFactor(h));
    col = mix(nightCol, col, smoothstep(-0.22, 0.04, h));
    float l = luminance(col);
#if LOOK_STYLE == 3
    // Snowy/overcast weather stays bright, soft, and grey-lavender
    col = mix(col, vec3(l) * vec3(0.95, 0.93, 1.04) * 0.94, rainStrength * 0.78);
#else
    col = mix(col, vec3(l) * vec3(0.9, 0.95, 1.05) * 0.75, rainStrength * 0.7);
#endif
    return max(col, 0.0) * AMBIENT_BRIGHTNESS;
#endif
}

// Round sun disc (replaces the square vanilla sun)
vec3 getSunDisc(vec3 dir) {
#if defined NETHER || defined END
    return vec3(0.0);
#elif LOOK_STYLE == 3
    // Dreamy: larger creamy-white sun disc with soft limb and warm inner corona
    float sd = dot(dir, normalize(sunPosition));
    float gs = clamp(SUN_GLOW_SIZE, 0.4, 2.5);
    float r2 = 0.00085 * gs;
    float disc = smoothstep(1.0 - r2 * 1.45, 1.0 - r2 * 0.45, sd);
    float limb = mix(0.74, 1.0, smoothstep(1.0 - r2 * 1.45, 1.0 - r2 * 0.10, sd));
    float corona = pow(max(sd, 0.0), 260.0 / gs) * 1.8;

    vec3 direct = getDirectLightColor() / max(SUN_BRIGHTNESS, 0.01);
    float directMax = max(max(direct.r, max(direct.g, direct.b)), 1e-4);
    vec3 sunTint = direct / directMax;
    vec3 creamyCol = mix(vec3(1.0, 0.97, 0.90), sunTint * vec3(1.0, 0.96, 0.89), 0.35);

    float h = getSunHeight();
    float vis = smoothstep(-0.04, 0.05, h) * (1.0 - rainStrength * 0.92);
    return creamyCol * (disc * limb * 18.0 + corona * 2.2) * vis;
#else
    float sd = dot(dir, normalize(sunPosition));
    float disc = smoothstep(0.99955, 0.99975, sd);
    float limb = mix(0.55, 1.0, smoothstep(0.99955, 0.99995, sd)); // darker edge, like the real sun
    vec3 col = getDirectLightColor() / max(SUN_BRIGHTNESS, 0.01);
    return col * disc * limb * 30.0 * (1.0 - rainStrength);
#endif
}

// Cheap analytic crater helper for procedural moon (no loops)
float moonCrater(vec2 p, vec2 center, float radius, vec2 light2D) {
    vec2 d = (p - center) / max(radius, 1e-4);
    float r = length(d);
    if (r > 1.35) return 0.0;
    float bowl = -0.14 * (1.0 - smoothstep(0.0, 0.88, r));
    float rim  = 0.10 * exp(-pow((r - 0.96) * 4.5, 2.0));
    float slope = dot(d / max(r, 0.05), light2D) * smoothstep(1.15, 0.55, r) * smoothstep(0.15, 0.65, r) * 0.08;
    return bowl + rim + slope;
}

// Realistic procedural moon disc (called in SKY_TEXTURED on the vanilla moon quad)
// Returns linear HDR rgb and smooth alpha in .a
vec4 getMoonDisc(vec3 dir) {
#if defined NETHER || defined END
    return vec4(0.0);
#else
    vec3 moonDir = normalize(moonPosition);
    float md = dot(dir, moonDir);
    if (md < 0.85) return vec4(0.0);

    vec3 up = normalize(upPosition);
    vec3 refUp = abs(dot(moonDir, up)) > 0.98 ? vec3(1.0, 0.0, 0.0) : up;
    vec3 moonRight = normalize(cross(refUp, moonDir));
    vec3 moonUp    = normalize(cross(moonDir, moonRight));

    float radius = 0.038 * MOON_SIZE;
    vec2 p = vec2(dot(dir, moonRight), dot(dir, moonUp)) / max(radius, 1e-4);
    float d2 = dot(p, p);
    if (d2 > 1.10) return vec4(0.0);

    float dist = sqrt(max(d2, 0.0));
    float aa = max(fwidth(dist), 0.018);
    float discMask = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, dist);
    if (discMask <= 0.001) return vec4(0.0);

    // Unit sphere normal facing the viewer
    float z = sqrt(max(1.0 - min(d2, 1.0), 0.0));
    vec3 n = vec3(p.x, p.y, z);

    // Real moon phase from uniform moonPhase (0 = full, 4 = new)
    float phi = float(moonPhase) * 0.78539816;
    vec3 phaseSun = normalize(vec3(-sin(phi), 0.12 * sin(phi), cos(phi)));
    float NdotL = dot(n, phaseSun);

    // Soft terminator + regolith-like broad diffuse + limb darkening
    float lit = smoothstep(-0.08, 0.22, NdotL);
    float diffuse = lit * mix(0.65, 1.0, pow(max(NdotL, 1e-4), 0.35));
    float limb = mix(0.60, 1.0, pow(max(z, 1e-4), 0.42));

    // Mild spherical warp so maria & craters curve near the limb
    vec2 sp = p / (0.65 + 0.35 * z);

    // Maria (dark basalt seas) from 3 cheap valueNoise octaves
    vec2 mp = sp * 2.2 + vec2(3.1, 1.7);
    float mNoise = valueNoise(mp) * 0.55
                 + valueNoise(mp * 2.1 + vec2(5.3, 2.9)) * 0.30
                 + valueNoise(mp * 4.3 + vec2(1.4, 7.1)) * 0.15;
    float maria = smoothstep(0.45, 0.67, mNoise + 0.08 * (-sp.x * 0.3 + sp.y * 0.4));

    vec3 highlandCol = vec3(0.92, 0.90, 0.85);
    vec3 mariaCol    = vec3(0.45, 0.47, 0.52);
    vec3 albedo = mix(highlandCol, mariaCol, maria);

    // 4 major craters + fine regolith grain
    vec2 l2 = phaseSun.xy;
    float c = moonCrater(sp, vec2( 0.20, -0.58), 0.18, l2)
            + moonCrater(sp, vec2(-0.28,  0.14), 0.16, l2)
            + moonCrater(sp, vec2( 0.46,  0.22), 0.13, l2)
            + moonCrater(sp, vec2(-0.08,  0.54), 0.12, l2);
    float grain = (valueNoise(sp * 11.5 + vec2(2.3, 8.1)) - 0.5) * 0.10;
    albedo = clamp(albedo * (1.0 + c + grain), 0.22, 1.15);

    // Lit side + faint cool earthshine on the dark side
    vec3 litCol     = albedo * vec3(1.00, 0.98, 0.92) * diffuse * limb;
    vec3 earthshine = albedo * vec3(0.16, 0.22, 0.36) * 0.13 * limb * (1.0 - lit);

    float moonH = dot(moonDir, up);
    float horizonFade = smoothstep(-0.02, 0.10, moonH);
    float weatherFade = 1.0 - rainStrength * 0.90;
    float dayDim = mix(1.0, 0.22, getDayFactor(getSunHeight()));

    vec3 col = (litCol + earthshine) * 1.9 * MOON_BRIGHTNESS * horizonFade * weatherFade * dayDim;
    return vec4(max(col, 0.0), discMask);
#endif
}

// Cheap hash stars with gentle twinkle, horizon & rain fade (zero loops)
vec3 getStars(vec3 viewDir) {
#if defined NETHER || defined END
    return vec3(0.0);
#else
    if (STAR_AMOUNT <= 0.001) return vec3(0.0);
    float h = getSunHeight();
    float vis = smoothstep(0.06, -0.15, h) * (1.0 - rainStrength * 0.95);
    if (vis <= 0.001) return vec3(0.0);

    vec3 dirW = normalize(mat3(gbufferModelViewInverse) * viewDir);
    float horizonFade = smoothstep(0.02, 0.28, dirW.y);
    if (horizonFade <= 0.001) return vec3(0.0);

    // Cube-face projection avoids pole pinching completely
    vec3 ad = abs(dirW);
    vec2 uv;
    float faceId;
    if (ad.y >= ad.x && ad.y >= ad.z) {
        uv = dirW.xz / max(ad.y, 1e-4);
        faceId = dirW.y > 0.0 ? 0.0 : 1.0;
    } else if (ad.x >= ad.z) {
        uv = dirW.yz / max(ad.x, 1e-4);
        faceId = dirW.x > 0.0 ? 2.0 : 3.0;
    } else {
        uv = dirW.xy / max(ad.z, 1e-4);
        faceId = dirW.z > 0.0 ? 4.0 : 5.0;
    }

    vec2 p = uv * 185.0;
    vec2 cell = floor(p);
    vec2 f = fract(p) - 0.5;

    vec2 seed = cell + faceId * 137.0;
    float r1 = hash12(seed);
    float threshold = clamp(1.0 - 0.036 * STAR_AMOUNT, 0.82, 0.999);
    if (r1 < threshold) return vec3(0.0);

    float r2 = hash12(seed + vec2(31.7, 17.3));
    float r3 = hash12(seed + vec2(71.3, 53.1));

    vec2 offset = (vec2(r2, r3) - 0.5) * 0.56;
    float d = length(f - offset);
    float size = mix(0.06, 0.16, fract(r1 * 47.3));
    float star = smoothstep(size, 0.0, d);
    star *= star;

    float twinkle = 0.72 + 0.28 * sin(frameTimeCounter * (1.8 + r2 * 3.4) + r3 * 62.8318);
    float mag = pow(max((r1 - threshold) / max(1.0 - threshold, 1e-4), 1e-4), 1.55);
    vec3 starCol = mix(vec3(0.76, 0.87, 1.00), vec3(1.00, 0.90, 0.76), r2);

    // Keep stars from poking through the moon disc
    float md = dot(viewDir, normalize(moonPosition));
    float moonFade = 1.0 - smoothstep(0.992, 0.998, md);

    float styleMul = 1.0;
#if (LOOK_STYLE == 0 && NIGHT_STYLE == 2) || (LOOK_STYLE == 2 && NIGHT_STYLE == 2)
    styleMul = 1.45;
#elif LOOK_STYLE == 1 && NIGHT_STYLE == 1
    styleMul = 0.55; // hazy blue-hour fog softens stars
#elif LOOK_STYLE == 1 && NIGHT_STYLE == 2
    styleMul = 0.40; // gloomy dark rainforest
#elif LOOK_STYLE == 3 && NIGHT_STYLE == 1
    styleMul = 0.70; // Dreamy lavender mist softens stars
#elif LOOK_STYLE == 3 && NIGHT_STYLE == 2
    styleMul = 1.30; // Dreamy starry violet sky
#endif

    float night = getNightFactor(h);
    return starCol * star * mag * twinkle * vis * horizonFade * moonFade * styleMul * (1.6 + 0.7 * night);
#endif
}

// Sky colour looking in direction dir (view space, normalised)
vec3 getSkyColor(vec3 dir) {
#if defined NETHER
    return toLinear(fogColor) * 0.9;
#elif defined END
    return vec3(0.025, 0.018, 0.04);
#else
    vec3 up = normalize(upPosition);
    vec3 sunDir = normalize(sunPosition);
    float h = getSunHeight();
    float y = dot(dir, up);
    float yy = clamp(y, 0.0, 1.0);
    float sd = dot(dir, sunDir);
    float towardSun = 0.5 + 0.5 * sd;

    float day = smoothstep(-0.1, 0.25, h);
    float sunset = getSunsetFactor(h);
    float night = getNightFactor(h);

    // Night zenith & horizon per LOOK_STYLE and NIGHT_STYLE
    // (horizonNight drives horizonHaze() fog colour at night)
    vec3 zenithNight  = vec3(0.008, 0.012, 0.030);
    vec3 horizonNight = vec3(0.022, 0.028, 0.050);
#if LOOK_STYLE == 1
    #if NIGHT_STYLE == 1
    // PNW Moody - Blue hour forest fog: faint silvery-blue sky + luminous blue-teal horizon fog
    zenithNight  = vec3(0.020, 0.038, 0.064);
    horizonNight = vec3(0.075, 0.125, 0.170);
    #elif NIGHT_STYLE == 2
    // PNW Moody - Dark rainforest: gloomy desaturated teal-grey with slight mist
    zenithNight  = vec3(0.004, 0.008, 0.011);
    horizonNight = vec3(0.022, 0.030, 0.035);
    #endif
#elif LOOK_STYLE == 2
    #if NIGHT_STYLE == 1
    // Clear Winter - Moonlit snow blue
    zenithNight  = vec3(0.014, 0.026, 0.058);
    horizonNight = vec3(0.055, 0.082, 0.135);
    #elif NIGHT_STYLE == 2
    // Clear Winter - Arctic starlight: deep clear midnight sky
    zenithNight  = vec3(0.005, 0.009, 0.024);
    horizonNight = vec3(0.018, 0.028, 0.052);
    #endif
#elif LOOK_STYLE == 3
    // Dreamy: soft periwinkle-violet night sky with gentle lavender horizon glow
    zenithNight  = vec3(0.020, 0.022, 0.052);
    horizonNight = vec3(0.058, 0.058, 0.108);
    #if NIGHT_STYLE == 1
    // Dreamy - Lavender mist night
    zenithNight  = vec3(0.028, 0.032, 0.068);
    horizonNight = vec3(0.085, 0.082, 0.140);
    #elif NIGHT_STYLE == 2
    // Dreamy - Starry violet night
    zenithNight  = vec3(0.012, 0.014, 0.038);
    horizonNight = vec3(0.036, 0.038, 0.078);
    #endif
#else
    #if NIGHT_STYLE == 1
    // Hearth Classic - Moonlit mist
    zenithNight  = vec3(0.012, 0.020, 0.044);
    horizonNight = vec3(0.042, 0.058, 0.092);
    #elif NIGHT_STYLE == 2
    // Hearth Classic - Starry clear
    zenithNight  = vec3(0.004, 0.007, 0.018);
    horizonNight = vec3(0.014, 0.020, 0.038);
    #endif
#endif

    zenithNight  *= NIGHT_BRIGHTNESS;
    horizonNight *= NIGHT_BRIGHTNESS * NIGHT_FOG;

#if MORNING_STYLE == 0 && MIDDAY_STYLE == 0 && AFTERNOON_STYLE == 0
    #if LOOK_STYLE == 3
    // Dreamy daytime: luminous pastel periwinkle overhead fading to soft creamy lavender-horizon
    float pastel = clamp(PASTEL_AMOUNT, 0.0, 1.5);
    vec3 dayZenith  = mix(vec3(0.24, 0.36, 0.60), vec3(0.36, 0.40, 0.68), clamp(pastel * 0.55, 0.0, 1.0));
    vec3 dayHorizon = mix(vec3(0.62, 0.66, 0.78), vec3(0.78, 0.72, 0.84), clamp(pastel * 0.60, 0.0, 1.0));
    vec3 zenith  = mix(zenithNight,  dayZenith,  day);
    vec3 horizon = mix(horizonNight, dayHorizon, day);
    vec3 sky = mix(zenith, horizon, pow(max(1.0 - yy, 0.0), 2.8));
    #else
    // daytime: a soft, slightly hazy blue (PNW air is rarely deep blue)
    vec3 zenith  = mix(zenithNight,  vec3(0.17, 0.28, 0.50), day);
    vec3 horizon = mix(horizonNight, vec3(0.50, 0.56, 0.64), day);
    vec3 sky = mix(zenith, horizon, pow(max(1.0 - yy, 0.0), 3.5));
    #endif
#else
    #if LOOK_STYLE == 3
    float pastel = clamp(PASTEL_AMOUNT, 0.0, 1.5);
    vec3 dayZenith  = mix(vec3(0.24, 0.36, 0.60), vec3(0.36, 0.40, 0.68), clamp(pastel * 0.55, 0.0, 1.0));
    vec3 dayHorizon = mix(vec3(0.62, 0.66, 0.78), vec3(0.78, 0.72, 0.84), clamp(pastel * 0.60, 0.0, 1.0));
    float dayPow = 2.8;
    #else
    vec3 dayZenith  = vec3(0.17, 0.28, 0.50);
    vec3 dayHorizon = vec3(0.50, 0.56, 0.64);
    float dayPow = 3.5;
    #endif

    float dayInt = 0.67 * clamp(DAY_INTENSITY, 0.5, 1.5);
    float mW = 0.0, dW = 0.0, aW = 0.0;

    vec3 mZenith = dayZenith,  mHorizon = dayHorizon;  float mPow = dayPow;
    vec3 mGlowTint = vec3(1.00, 0.90, 0.74); float mGlowMul = 1.0; float mExtraGlow = 0.0; float mIceHalo = 0.0;

    vec3 dZenith = dayZenith,  dHorizon = dayHorizon;  float dPow = dayPow;
    vec3 dGlowTint = vec3(1.00, 0.90, 0.74); float dGlowMul = 1.0; float dExtraGlow = 0.0; float dIceHalo = 0.0;

    vec3 aZenith = dayZenith,  aHorizon = dayHorizon;  float aPow = dayPow;
    vec3 aGlowTint = vec3(1.00, 0.90, 0.74); float aGlowMul = 1.0; float aExtraGlow = 0.0; float aIceHalo = 0.0;

    #if MORNING_STYLE != 0
    mW = todMorning(h);
        #if LOOK_STYLE == 1
            #if MORNING_STYLE == 1
            // PNW Moody - Burning-off marine layer: cool pale-blue sky clearing over bright mist horizon
            mZenith    = vec3(0.20, 0.30, 0.44);
            mHorizon   = vec3(0.62, 0.68, 0.72);
            mPow       = 2.2;
            mGlowTint  = vec3(1.00, 0.93, 0.80);
            mGlowMul   = 1.05;
            mExtraGlow = 0.20;
            #elif MORNING_STYLE == 2
            // PNW Moody - Drizzle grey: low cool-slate overcast deck
            mZenith    = vec3(0.30, 0.36, 0.42);
            mHorizon   = vec3(0.54, 0.60, 0.64);
            mPow       = 1.6;
            mGlowTint  = vec3(0.88, 0.93, 0.97);
            mGlowMul   = 0.28;
            #endif
        #elif LOOK_STYLE == 2
            #if MORNING_STYLE == 1
            // Clear Winter - Diamond-dust sparkle: crisp pale-cobalt sky with faint 22-deg ice halo
            mZenith    = vec3(0.10, 0.24, 0.56);
            mHorizon   = vec3(0.58, 0.70, 0.86);
            mPow       = 3.4;
            mGlowTint  = vec3(1.00, 0.98, 0.96);
            mGlowMul   = 0.95;
            mIceHalo   = 0.28;
            #elif MORNING_STYLE == 2
            // Clear Winter - Pale blue cold: crisp frigid ice-blue gradient
            mZenith    = vec3(0.12, 0.26, 0.54);
            mHorizon   = vec3(0.52, 0.66, 0.84);
            mPow       = 3.0;
            mGlowTint  = vec3(0.92, 0.96, 1.02);
            mGlowMul   = 0.78;
            #endif
        #elif LOOK_STYLE == 3
            #if MORNING_STYLE == 1
            // Dreamy - Soft mint-blue: pastel robin's-egg zenith fading to airy mint-cream horizon
            mZenith    = vec3(0.24, 0.46, 0.68);
            mHorizon   = vec3(0.68, 0.82, 0.84);
            mPow       = 2.6;
            mGlowTint  = vec3(0.96, 1.00, 0.96);
            mGlowMul   = 1.00;
            #elif MORNING_STYLE == 2
            // Dreamy - Dewy haze: misty pearl-lavender sky with soft luminous scatter
            mZenith    = vec3(0.38, 0.44, 0.66);
            mHorizon   = vec3(0.78, 0.76, 0.86);
            mPow       = 2.0;
            mGlowTint  = vec3(1.00, 0.95, 0.92);
            mGlowMul   = 0.92;
            mExtraGlow = 0.16;
            #endif
        #else
            #if MORNING_STYLE == 1
            // Hearth Classic - Fresh cool crisp: bright clean azure morning sky
            mZenith    = vec3(0.10, 0.26, 0.60);
            mHorizon   = vec3(0.48, 0.64, 0.80);
            mPow       = 3.8;
            mGlowTint  = vec3(0.98, 0.98, 1.00);
            mGlowMul   = 0.85;
            #elif MORNING_STYLE == 2
            // Hearth Classic - Misty soft: pale milky-blue morning haze
            mZenith    = vec3(0.28, 0.38, 0.54);
            mHorizon   = vec3(0.66, 0.70, 0.76);
            mPow       = 2.2;
            mGlowTint  = vec3(1.00, 0.94, 0.84);
            mGlowMul   = 0.80;
            mExtraGlow = 0.18;
            #endif
        #endif
    #endif

    #if MIDDAY_STYLE != 0
    dW = todMidday(h);
        #if LOOK_STYLE == 1
            #if MIDDAY_STYLE == 1
            // PNW Moody - Sun breaks after rain: deep stormy blue-grey zenith, misty bright horizon break
            dZenith    = vec3(0.09, 0.16, 0.28);
            dHorizon   = vec3(0.46, 0.53, 0.59);
            dPow       = 3.0;
            dGlowTint  = vec3(1.00, 0.93, 0.78);
            dGlowMul   = 1.35;
            dExtraGlow = 0.32;
            #elif MIDDAY_STYLE == 2
            // PNW Moody - Marine-layer grey: cool pearly silver overcast deck
            dZenith    = vec3(0.36, 0.42, 0.48);
            dHorizon   = vec3(0.62, 0.67, 0.71);
            dPow       = 1.7;
            dGlowTint  = vec3(0.92, 0.95, 0.98);
            dGlowMul   = 0.35;
            #endif
        #elif LOOK_STYLE == 2
            #if MIDDAY_STYLE == 1
            // Clear Winter - Bluebird powder day: deep alpine cobalt sky, crisp glacial horizon
            dZenith    = vec3(0.05, 0.17, 0.54);
            dHorizon   = vec3(0.46, 0.62, 0.82);
            dPow       = 4.4;
            dGlowTint  = vec3(1.00, 0.97, 0.92);
            dGlowMul   = 0.85;
            #elif MIDDAY_STYLE == 2
            // Clear Winter - Ice-crystal haze: bright milky sky + 22-degree sun halo
            dZenith    = vec3(0.38, 0.48, 0.64);
            dHorizon   = vec3(0.76, 0.80, 0.86);
            dPow       = 2.1;
            dGlowTint  = vec3(0.98, 0.98, 1.02);
            dGlowMul   = 0.95;
            dIceHalo   = 0.42;
            #endif
        #elif LOOK_STYLE == 3
            #if MIDDAY_STYLE == 1
            // Dreamy - Cotton-candy: pastel sky blue overhead, soft pink-lavender horizon
            dZenith    = vec3(0.28, 0.42, 0.74);
            dHorizon   = vec3(0.86, 0.70, 0.82);
            dPow       = 2.6;
            dGlowTint  = vec3(1.00, 0.92, 0.92);
            dGlowMul   = 1.05;
            #elif MIDDAY_STYLE == 2
            // Dreamy - Golden lazy: warm sky blue fading into soft peach-honey haze
            dZenith    = vec3(0.24, 0.36, 0.58);
            dHorizon   = vec3(0.88, 0.74, 0.64);
            dPow       = 2.4;
            dGlowTint  = vec3(1.00, 0.86, 0.64);
            dGlowMul   = 1.30;
            dExtraGlow = 0.22;
            #endif
        #else
            #if MIDDAY_STYLE == 1
            // Hearth Classic - Crisp clear: deep blue sky, light clean horizon haze
            dZenith    = vec3(0.08, 0.22, 0.58);
            dHorizon   = vec3(0.44, 0.58, 0.74);
            dPow       = 4.2;
            dGlowTint  = vec3(1.00, 0.96, 0.88);
            dGlowMul   = 0.80;
            #elif MIDDAY_STYLE == 2
            // Hearth Classic - Soft overcast: bright silvery sky, even horizon
            dZenith    = vec3(0.42, 0.46, 0.52);
            dHorizon   = vec3(0.68, 0.71, 0.75);
            dPow       = 1.8;
            dGlowTint  = vec3(0.96, 0.97, 1.00);
            dGlowMul   = 0.40;
            #endif
        #endif
    #endif

    #if AFTERNOON_STYLE != 0
    aW = todAfternoon(h);
        #if LOOK_STYLE == 1
            #if AFTERNOON_STYLE == 1
            // PNW Moody - Low-angle forest shafts: deep cool-blue zenith, warm amber-haze horizon
            aZenith    = vec3(0.11, 0.20, 0.34);
            aHorizon   = vec3(0.64, 0.58, 0.48);
            aPow       = 2.8;
            aGlowTint  = vec3(1.00, 0.80, 0.48);
            aGlowMul   = 1.45;
            aExtraGlow = 0.36;
            #elif AFTERNOON_STYLE == 2
            // PNW Moody - Squally showers: dark stormy blue-grey zenith, bright silver-grey horizon
            aZenith    = vec3(0.14, 0.20, 0.28);
            aHorizon   = vec3(0.46, 0.52, 0.58);
            aPow       = 2.2;
            aGlowTint  = vec3(0.88, 0.92, 0.98);
            aGlowMul   = 0.45;
            #endif
        #elif LOOK_STYLE == 2
            #if AFTERNOON_STYLE == 1
            // Clear Winter - Long blue shadows, golden snow: deep cobalt zenith, warm gold horizon
            aZenith    = vec3(0.07, 0.19, 0.54);
            aHorizon   = vec3(0.76, 0.68, 0.56);
            aPow       = 3.6;
            aGlowTint  = vec3(1.00, 0.82, 0.50);
            aGlowMul   = 1.25;
            aExtraGlow = 0.18;
            #elif AFTERNOON_STYLE == 2
            // Clear Winter - Flat white: bright even milky winter overcast
            aZenith    = vec3(0.56, 0.60, 0.68);
            aHorizon   = vec3(0.80, 0.82, 0.86);
            aPow       = 1.5;
            aGlowTint  = vec3(0.96, 0.97, 1.00);
            aGlowMul   = 0.30;
            #endif
        #elif LOOK_STYLE == 3
            #if AFTERNOON_STYLE == 1
            // Dreamy - Apricot glow: soft sky blue fading to warm glowing apricot horizon
            aZenith    = vec3(0.26, 0.38, 0.64);
            aHorizon   = vec3(0.92, 0.72, 0.58);
            aPow       = 2.4;
            aGlowTint  = vec3(1.00, 0.80, 0.56);
            aGlowMul   = 1.35;
            aExtraGlow = 0.28;
            #elif AFTERNOON_STYLE == 2
            // Dreamy - Lavender drift: soft periwinkle-violet zenith to pastel lilac horizon
            aZenith    = vec3(0.34, 0.34, 0.68);
            aHorizon   = vec3(0.78, 0.68, 0.88);
            aPow       = 2.3;
            aGlowTint  = vec3(0.98, 0.90, 1.00);
            aGlowMul   = 0.95;
            #endif
        #else
            #if AFTERNOON_STYLE == 1
            // Hearth Classic - Warm golden: clear blue overhead, warm golden-cream horizon
            aZenith    = vec3(0.15, 0.26, 0.50);
            aHorizon   = vec3(0.74, 0.66, 0.54);
            aPow       = 3.0;
            aGlowTint  = vec3(1.00, 0.82, 0.54);
            aGlowMul   = 1.28;
            aExtraGlow = 0.22;
            #elif AFTERNOON_STYLE == 2
            // Hearth Classic - Hazy summer: warm dusty-blue zenith, creamy hazy horizon
            aZenith    = vec3(0.24, 0.34, 0.54);
            aHorizon   = vec3(0.72, 0.70, 0.66);
            aPow       = 2.2;
            aGlowTint  = vec3(1.00, 0.90, 0.72);
            aGlowMul   = 1.15;
            aExtraGlow = 0.26;
            #endif
        #endif
    #endif

    float wSum = mW + dW + aW;
    float dayMix = clamp(wSum * dayInt, 0.0, 1.0);
    vec3 styleZenith  = dayZenith;
    vec3 styleHorizon = dayHorizon;
    float stylePow    = dayPow;
    vec3 dayGlowTint  = vec3(1.00, 0.90, 0.74);
    float dayGlowMul  = 1.0;
    float extraDayGlow = 0.0;
    float iceHaloAmt   = 0.0;

    if (wSum > 1e-4) {
        float invW = 1.0 / wSum;
        styleZenith  = (mZenith    * mW + dZenith    * dW + aZenith    * aW) * invW;
        styleHorizon = (mHorizon   * mW + dHorizon   * dW + aHorizon   * aW) * invW;
        stylePow     = (mPow       * mW + dPow       * dW + aPow       * aW) * invW;
        dayGlowTint  = (mGlowTint  * mW + dGlowTint  * dW + aGlowTint  * aW) * invW;
        dayGlowMul   = (mGlowMul   * mW + dGlowMul   * dW + aGlowMul   * aW) * invW;
        extraDayGlow = (mExtraGlow * mW + dExtraGlow * dW + aExtraGlow * aW) * invW;
        iceHaloAmt   = (mIceHalo   * mW + dIceHalo   * dW + aIceHalo   * aW) * invW;
    }

    dayZenith  = mix(dayZenith,  styleZenith,  dayMix);
    dayHorizon = mix(dayHorizon, styleHorizon, dayMix);
    dayPow     = mix(dayPow,     stylePow,     dayMix);

    vec3 zenith  = mix(zenithNight,  dayZenith,  day);
    vec3 horizon = mix(horizonNight, dayHorizon, day);
    vec3 sky = mix(zenith, horizon, pow(max(1.0 - yy, 1e-4), dayPow));
#endif

    // Low-sun sky palette (sunrise on morning side, sunset on evening side)
#if LOOK_STYLE == 3
    // Dreamy base: soft pastel lavender-pink overhead fading to warm peach-cream near horizon
    vec3 baseLow        = vec3(1.00, 0.80, 0.66) * 1.20;
    vec3 baseMid        = vec3(0.96, 0.66, 0.76) * 0.96;
    vec3 baseHigh       = vec3(0.54, 0.48, 0.78) * 0.82;
    vec3 baseAntiSun    = vec3(0.84, 0.82, 1.00) * 0.92;
    vec3 baseGlowCol    = vec3(1.00, 0.88, 0.74);
    float baseGlowMul   = 1.15;
    float baseExtraHaze = 0.22;
#else
    vec3 baseLow        = vec3(1.00, 0.54, 0.22) * 1.25;
    vec3 baseMid        = vec3(0.90, 0.48, 0.44) * 0.75;
    vec3 baseHigh       = vec3(0.30, 0.34, 0.60) * 0.55;
    vec3 baseAntiSun    = vec3(0.62, 0.60, 0.92) * 0.75;
    vec3 baseGlowCol    = vec3(1.00, 0.50, 0.18);
    float baseGlowMul   = 1.0;
    float baseExtraHaze = 0.0;
#endif

#if SUNRISE_STYLE == 0 && SUNSET_STYLE == 0
    vec3 setLow         = baseLow;
    vec3 setMid         = baseMid;
    vec3 setHigh        = baseHigh;
    vec3 antiSunTint    = baseAntiSun;
    vec3 setGlowCol     = baseGlowCol;
    float glowMul       = baseGlowMul;
    float extraHazeGlow = baseExtraHaze;
#else
    vec3 riseLow = baseLow, riseMid = baseMid, riseHigh = baseHigh;
    vec3 riseAntiSun = baseAntiSun, riseGlowCol = baseGlowCol;
    float riseGlowMul = baseGlowMul, riseExtraHaze = baseExtraHaze;
    float pinkSeamAmt = 0.0;

    vec3 duskLow = baseLow, duskMid = baseMid, duskHigh = baseHigh;
    vec3 duskAntiSun = baseAntiSun, duskGlowCol = baseGlowCol;
    float duskGlowMul = baseGlowMul, duskExtraHaze = baseExtraHaze;

    // Morning-side (sunrise) palette
    #if LOOK_STYLE == 1
        #if SUNRISE_STYLE == 1
        // PNW Moody - Fog-bound grey dawn with a pink seam on the horizon
        riseLow       = vec3(0.96, 0.56, 0.64) * 0.95;
        riseMid       = vec3(0.46, 0.50, 0.55) * 0.66;
        riseHigh      = vec3(0.24, 0.28, 0.34) * 0.52;
        riseAntiSun   = vec3(0.68, 0.74, 0.80) * 0.82;
        riseGlowCol   = vec3(1.00, 0.64, 0.70);
        riseGlowMul   = 0.45;
        pinkSeamAmt   = 0.55;
        #elif SUNRISE_STYLE == 2
        // PNW Moody - Mt. Rainier dawn alpenglow: cool lavender -> crisp rose -> soft coral
        riseLow       = vec3(1.00, 0.66, 0.54) * 1.14;
        riseMid       = vec3(0.86, 0.48, 0.62) * 0.82;
        riseHigh      = vec3(0.28, 0.30, 0.60) * 0.62;
        riseAntiSun   = vec3(0.74, 0.72, 0.98) * 0.86;
        riseGlowCol   = vec3(1.00, 0.66, 0.58);
        riseGlowMul   = 0.64;
        #endif
    #elif LOOK_STYLE == 2
        #if SUNRISE_STYLE == 1
        // Clear Winter - Frosty pink dawn: icy periwinkle -> pale rose -> frosted pink horizon
        riseLow       = vec3(1.00, 0.72, 0.70) * 1.14;
        riseMid       = vec3(0.88, 0.56, 0.68) * 0.84;
        riseHigh      = vec3(0.24, 0.32, 0.64) * 0.64;
        riseAntiSun   = vec3(0.76, 0.78, 1.02) * 0.88;
        riseGlowCol   = vec3(1.00, 0.74, 0.72);
        riseGlowMul   = 0.72;
        #elif SUNRISE_STYLE == 2
        // Clear Winter - Deep orange cold dawn: burnt copper-orange horizon under frigid steel blue
        riseLow       = vec3(1.00, 0.44, 0.12) * 1.48;
        riseMid       = vec3(0.90, 0.40, 0.24) * 0.84;
        riseHigh      = vec3(0.16, 0.28, 0.58) * 0.58;
        riseAntiSun   = vec3(0.50, 0.60, 0.88) * 0.76;
        riseGlowCol   = vec3(1.00, 0.48, 0.14);
        riseGlowMul   = 1.25;
        riseExtraHaze = 0.18;
        #endif
    #elif LOOK_STYLE == 3
        #if SUNRISE_STYLE == 1
        // Dreamy - Peach-lilac dawn: airy lilac zenith -> creamy peach horizon
        riseLow       = vec3(1.00, 0.78, 0.64) * 1.22;
        riseMid       = vec3(0.88, 0.68, 0.86) * 0.96;
        riseHigh      = vec3(0.52, 0.48, 0.82) * 0.84;
        riseAntiSun   = vec3(0.86, 0.82, 1.02) * 0.94;
        riseGlowCol   = vec3(1.00, 0.84, 0.72);
        riseGlowMul   = 1.10;
        riseExtraHaze = 0.20;
        #elif SUNRISE_STYLE == 2
        // Dreamy - Rose-gold dawn: luminous rose-gold horizon -> soft blush-violet sky
        riseLow       = vec3(1.00, 0.74, 0.52) * 1.28;
        riseMid       = vec3(0.98, 0.64, 0.70) * 0.96;
        riseHigh      = vec3(0.48, 0.44, 0.74) * 0.80;
        riseAntiSun   = vec3(0.82, 0.78, 0.98) * 0.90;
        riseGlowCol   = vec3(1.00, 0.78, 0.58);
        riseGlowMul   = 1.26;
        riseExtraHaze = 0.24;
        #endif
    #else
        #if SUNRISE_STYLE == 1
        // Hearth Classic - Rosy pastel dawn: periwinkle -> soft rose -> blush peach
        riseLow       = vec3(1.00, 0.70, 0.62) * 1.16;
        riseMid       = vec3(0.90, 0.56, 0.64) * 0.82;
        riseHigh      = vec3(0.30, 0.36, 0.64) * 0.60;
        riseAntiSun   = vec3(0.72, 0.70, 0.96) * 0.84;
        riseGlowCol   = vec3(1.00, 0.70, 0.62);
        riseGlowMul   = 0.88;
        #elif SUNRISE_STYLE == 2
        // Hearth Classic - Golden clear dawn: clean blue zenith -> crisp champagne-gold horizon
        riseLow       = vec3(1.00, 0.66, 0.26) * 1.38;
        riseMid       = vec3(0.94, 0.62, 0.38) * 0.84;
        riseHigh      = vec3(0.20, 0.34, 0.60) * 0.58;
        riseAntiSun   = vec3(0.58, 0.66, 0.88) * 0.78;
        riseGlowCol   = vec3(1.00, 0.68, 0.28);
        riseGlowMul   = 1.22;
        riseExtraHaze = 0.14;
        #endif
    #endif

    // Evening-side (sunset) palette
    #if LOOK_STYLE == 1
        #if SUNSET_STYLE == 1
        // PNW Moody - Mt. Rainier alpenglow: pastel lavender -> dusty rose -> peach/apricot, calm low haze
        duskLow       = vec3(1.00, 0.66, 0.44) * 1.15;
        duskMid       = vec3(0.88, 0.46, 0.56) * 0.82;
        duskHigh      = vec3(0.34, 0.28, 0.58) * 0.62;
        duskAntiSun   = vec3(0.76, 0.68, 0.96) * 0.86;
        duskGlowCol   = vec3(1.00, 0.64, 0.52);
        duskGlowMul   = 0.58;
        #elif SUNSET_STYLE == 2
        // PNW Moody - Cascades golden hour: thick golden-amber valley haze, strong backlit glow
        duskLow       = vec3(1.00, 0.58, 0.14) * 1.55;
        duskMid       = vec3(0.95, 0.50, 0.20) * 0.92;
        duskHigh      = vec3(0.24, 0.32, 0.44) * 0.50;
        duskAntiSun   = vec3(0.46, 0.50, 0.58) * 0.68;
        duskGlowCol   = vec3(1.00, 0.56, 0.14);
        duskGlowMul   = 1.65;
        duskExtraHaze = 0.36;
        #endif
    #elif LOOK_STYLE == 2
        #if SUNSET_STYLE == 1
        // Clear Winter - Alpine alpenglow: crisp periwinkle -> rose -> soft apricot
        duskLow       = vec3(1.00, 0.68, 0.52) * 1.16;
        duskMid       = vec3(0.90, 0.46, 0.58) * 0.84;
        duskHigh      = vec3(0.28, 0.30, 0.62) * 0.64;
        duskAntiSun   = vec3(0.74, 0.72, 1.00) * 0.88;
        duskGlowCol   = vec3(1.00, 0.66, 0.58);
        duskGlowMul   = 0.70;
        #elif SUNSET_STYLE == 2
        // Clear Winter - Winter gold: pale champagne-gold horizon, steel-blue zenith
        duskLow       = vec3(1.00, 0.68, 0.28) * 1.38;
        duskMid       = vec3(0.96, 0.58, 0.34) * 0.84;
        duskHigh      = vec3(0.22, 0.34, 0.58) * 0.58;
        duskAntiSun   = vec3(0.56, 0.64, 0.88) * 0.76;
        duskGlowCol   = vec3(1.00, 0.66, 0.26);
        duskGlowMul   = 1.25;
        duskExtraHaze = 0.16;
        #endif
    #elif LOOK_STYLE == 3
        #if SUNSET_STYLE == 1
        // Dreamy - Cotton-candy rose alpenglow
        duskLow       = vec3(1.00, 0.76, 0.70) * 1.18;
        duskMid       = vec3(0.98, 0.60, 0.78) * 0.98;
        duskHigh      = vec3(0.52, 0.44, 0.80) * 0.84;
        duskAntiSun   = vec3(0.86, 0.80, 1.02) * 0.94;
        duskGlowCol   = vec3(1.00, 0.82, 0.78);
        duskGlowMul   = 1.05;
        duskExtraHaze = 0.18;
        #elif SUNSET_STYLE == 2
        // Dreamy - Honey peach golden hour
        duskLow       = vec3(1.00, 0.78, 0.48) * 1.30;
        duskMid       = vec3(0.98, 0.68, 0.60) * 0.96;
        duskHigh      = vec3(0.46, 0.48, 0.72) * 0.78;
        duskAntiSun   = vec3(0.78, 0.78, 0.96) * 0.88;
        duskGlowCol   = vec3(1.00, 0.84, 0.56);
        duskGlowMul   = 1.30;
        duskExtraHaze = 0.28;
        #endif
    #else
        #if SUNSET_STYLE == 1
        // Hearth Classic - Rose alpenglow
        duskLow       = vec3(1.00, 0.62, 0.44) * 1.18;
        duskMid       = vec3(0.90, 0.48, 0.54) * 0.80;
        duskHigh      = vec3(0.32, 0.30, 0.58) * 0.58;
        duskAntiSun   = vec3(0.70, 0.64, 0.94) * 0.82;
        duskGlowCol   = vec3(1.00, 0.60, 0.48);
        duskGlowMul   = 0.85;
        #elif SUNSET_STYLE == 2
        // Hearth Classic - Amber golden hour
        duskLow       = vec3(1.00, 0.56, 0.16) * 1.42;
        duskMid       = vec3(0.94, 0.50, 0.26) * 0.86;
        duskHigh      = vec3(0.26, 0.33, 0.50) * 0.52;
        duskAntiSun   = vec3(0.54, 0.54, 0.72) * 0.72;
        duskGlowCol   = vec3(1.00, 0.54, 0.16);
        duskGlowMul   = 1.35;
        duskExtraHaze = 0.20;
        #endif
    #endif

    float mSide = todMorningSide();
    vec3 setLow         = mix(duskLow,       riseLow,       mSide);
    vec3 setMid         = mix(duskMid,       riseMid,       mSide);
    vec3 setHigh        = mix(duskHigh,      riseHigh,      mSide);
    vec3 antiSunTint    = mix(duskAntiSun,   riseAntiSun,   mSide);
    vec3 setGlowCol     = mix(duskGlowCol,   riseGlowCol,   mSide);
    float glowMul       = mix(duskGlowMul,   riseGlowMul,   mSide);
    float extraHazeGlow = mix(duskExtraHaze, riseExtraHaze, mSide);
#endif

#if LOOK_STYLE == 3
    // Blend toward slightly softer pastel lift based on PASTEL_AMOUNT
    setLow  = mix(setLow * 0.94,  mix(setLow,  vec3(luminance(setLow))  * vec3(1.04, 0.96, 0.94), 0.18), clamp(pastel, 0.0, 1.5) * 0.67);
    setMid  = mix(setMid * 0.92,  mix(setMid,  vec3(luminance(setMid))  * vec3(1.04, 0.94, 1.04), 0.18), clamp(pastel, 0.0, 1.5) * 0.67);
    setHigh = mix(setHigh * 0.90, mix(setHigh, vec3(luminance(setHigh)) * vec3(0.98, 0.94, 1.08), 0.18), clamp(pastel, 0.0, 1.5) * 0.67);
#endif

    vec3 setSky = mix(setMid, setLow, exp(-yy * 9.0));
    setSky = mix(setHigh, setSky, exp(-yy * 2.6));
#if LOOK_STYLE == 1 && SUNRISE_STYLE == 1
    // Narrow glowing pink seam along the horizon beneath the grey fog deck
    float seamBand = exp(-yy * 24.0) * (0.45 + 0.55 * pow(max(towardSun, 0.0), 1.4));
    setSky += vec3(1.00, 0.54, 0.64) * seamBand * pinkSeamAmt * todMorningSide();
#endif
    // away from the sun the colours turn dimmer / cooler
    setSky = mix(setSky * antiSunTint, setSky, pow(max(towardSun, 0.0), 1.5));
    float setMix = clamp(sunset * 0.92 * SUNSET_INTENSITY, 0.0, 1.0);
    sky = mix(sky, setSky, setMix);

    if (y < 0.0) sky = mix(sky, sky * 0.35, smoothstep(0.0, 0.35, -y));

    // glow around the sun, big and soft through the haze
    float g = max(sd, 0.0);
#if LOOK_STYLE == 3
    float gs = clamp(SUN_GLOW_SIZE, 0.4, 2.5);
    vec3 baseDayGlowCol = vec3(1.00, 0.95, 0.86);
    #if MORNING_STYLE != 0 || MIDDAY_STYLE != 0 || AFTERNOON_STYLE != 0
    baseDayGlowCol = mix(baseDayGlowCol, dayGlowTint, dayMix);
    float effDayGlowMul = mix(1.0, dayGlowMul, dayMix);
    #else
    float effDayGlowMul = 1.0;
    #endif
    vec3 glowCol = mix(baseDayGlowCol, setGlowCol, sunset);
    float effGlowMul = mix(effDayGlowMul, glowMul * SUNSET_INTENSITY, sunset);
    float sunGlow = (pow(g, 3.0 / gs) * 0.28 + pow(g, 16.0 / gs) * 0.52 + pow(g, 96.0 / gs) * 0.95)
                  * (day * 0.62 + sunset * 0.95) * effGlowMul;
    sunGlow += pow(g, 2.2 / gs) * extraHazeGlow * sunset * SUNSET_INTENSITY * exp(-yy * 3.8);
    #if MORNING_STYLE != 0 || MIDDAY_STYLE != 0 || AFTERNOON_STYLE != 0
    sunGlow += pow(max(g, 1e-4), 3.0 / gs) * extraDayGlow * dayMix * exp(-yy * 2.8);
    #endif
    sky += glowCol * sunGlow * (1.0 - rainStrength * 0.82);
#else
    vec3 baseDayGlowCol = vec3(1.0, 0.86, 0.68);
    #if MORNING_STYLE != 0 || MIDDAY_STYLE != 0 || AFTERNOON_STYLE != 0
    baseDayGlowCol = mix(baseDayGlowCol, dayGlowTint, dayMix);
    float effDayGlowMul = mix(1.0, dayGlowMul, dayMix);
    #else
    float effDayGlowMul = 1.0;
    #endif
    vec3 glowCol = mix(baseDayGlowCol, setGlowCol, sunset);
    float effGlowMul = mix(effDayGlowMul, glowMul * SUNSET_INTENSITY, sunset);
    float sunGlow = (pow(g, 4.0) * 0.30 + pow(g, 32.0) * 0.55 + pow(g, 256.0) * 1.2) * (day * 0.55 + sunset) * effGlowMul;
    // Extra broad golden valley haze scatter for backlit golden-hour styles (feeds stronger godrays)
    sunGlow += pow(g, 2.5) * extraHazeGlow * sunset * SUNSET_INTENSITY * exp(-yy * 4.5);
    #if MORNING_STYLE != 0 || MIDDAY_STYLE != 0 || AFTERNOON_STYLE != 0
    sunGlow += pow(max(g, 1e-4), 3.5) * extraDayGlow * dayMix * (0.45 + 0.55 * exp(-yy * 3.0));
    #endif
    sky += glowCol * sunGlow * (1.0 - rainStrength * 0.8);
    #if MORNING_STYLE != 0 || MIDDAY_STYLE != 0 || AFTERNOON_STYLE != 0
    // 22-degree ice-crystal sun halo (Clear Winter - Diamond-dust sparkle / Ice-crystal haze)
    if (iceHaloAmt > 0.0) {
        float dh = (sd - 0.927) * 28.0;
        float halo22 = exp(-dh * dh);
        sky += vec3(0.96, 0.98, 1.04) * halo22 * iceHaloAmt * dayMix * (1.0 - rainStrength * 0.85);
    }
    #endif
#endif

    // Subtle halo around the moon (scales with phase, widens in haze/rain)
    vec3 moonDir = normalize(moonPosition);
    float m = max(dot(dir, moonDir), 0.0);
    float moonUp = smoothstep(-0.04, 0.10, dot(moonDir, up));
    float phaseIllum = getMoonPhaseIllum();
    float hazeAmt = clamp(rainStrength * 0.85 + max(NIGHT_FOG - 1.0, 0.0) * 0.5, 0.0, 1.0);
    float haloTight = pow(m, 64.0) * 0.08 * (1.0 - rainStrength * 0.7);
    float haloMid   = pow(m, 20.0) * 0.055 * (1.0 + hazeAmt * 0.65);
    float haloWide  = pow(m, 5.0)  * 0.026 * hazeAmt * (1.0 - rainStrength * 0.45);
    vec3 haloCol = mix(vec3(0.25, 0.35, 0.60), vec3(0.54, 0.66, 0.84), hazeAmt);
    sky += haloCol * (haloTight + haloMid + haloWide) * night * moonUp * mix(0.20, 1.0, phaseIllum) * MOON_HALO * NIGHT_BRIGHTNESS;

    float l = luminance(sky);
#if LOOK_STYLE == 3
    // Overcast / snowy sky: luminous soft grey-lavender blanket, never dark
    float overcastFloor = mix(0.30, 0.04, night);
    vec3 overcastSky = vec3(max(l, overcastFloor)) * vec3(0.95, 0.93, 1.03) * 0.92;
    sky = mix(sky, overcastSky, rainStrength * 0.88);
#else
    sky = mix(sky, vec3(l) * vec3(0.85, 0.9, 1.0) * 0.6, rainStrength * 0.85);
#endif
    return max(sky, 0.0) * SKY_BRIGHTNESS;
#endif
}

// ---------------------------------------------------------------
//  Volumetric clouds: a layer of soft 3D clouds lit by the sun
// ---------------------------------------------------------------
const float CLOUD_BOTTOM = 230.0;
const float CLOUD_TOP    = 360.0;

float cloudFbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += valueNoise(p) * a;
        p = p * 2.03 + vec2(17.1, 9.7);
        a *= 0.5;
    }
    return v;
}

float cloudDensity(vec3 wp) {
    float h = (wp.y - CLOUD_BOTTOM) / (CLOUD_TOP - CLOUD_BOTTOM);
    if (h < 0.0 || h > 1.0) return 0.0;
    vec3 q = wp + vec3(frameTimeCounter * 1.5, 0.0, frameTimeCounter * 0.5);

    // large shapes: where the clouds are
    vec2 p = q.xz * 0.0019;
    float base = cloudFbm(p + vec2(valueNoise(p * 0.4) * 0.9));
    float coverage = CLOUD_COVERAGE + rainStrength * 0.35;
    // flat bottoms, tops that narrow into rounded heads
    float shape = smoothstep(0.0, 0.07, h) * smoothstep(1.0, 0.45, h);
    float d = base - (1.0 - coverage) - (1.0 - shape) * 0.32 - h * 0.08;
    if (d <= 0.0) return 0.0;

    // small 3D detail eats into the edges: lumpy, cauliflower-like puffs
    vec3 dq = q * vec3(1.0, 1.4, 1.0);
    float detail = valueNoise3D(dq * 0.020) * 0.62 + valueNoise3D(dq * 0.052) * 0.38;
    d -= detail * (0.20 + 0.10 * (1.0 - h));
    return clamp(d * 6.0, 0.0, 1.0);
}

float henyeyGreenstein(float mu, float g) {
    float g2 = g * g;
    return (1.0 - g2) / pow(max(1.0 + g2 - 2.0 * g * mu, 1e-4), 1.5);
}

// Flat clouds: one painted layer, lit with a cheap trick. Much faster than 3D.
vec4 getFlatClouds(vec3 viewDir) {
#if !defined NETHER && !defined END
    vec3 dir = mat3(gbufferModelViewInverse) * viewDir;
    if (dir.y < 0.015) return vec4(0.0, 0.0, 0.0, 1.0);
    const float height = 260.0;
    float t = (height - cameraPosition.y) / dir.y;
    if (t < 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

    vec2 wind = vec2(frameTimeCounter * 1.5, frameTimeCounter * 0.5);
    vec2 p = (cameraPosition.xz + dir.xz * t + wind) * 0.0021;
    float coverage = CLOUD_COVERAGE + rainStrength * 0.35;

#if LOOK_STYLE == 3
    // Dreamy puffy cumulus: two-scale rounded clumps, 1 offset self-shadow sample,
    // silver lining near sun, grey-lavender undersides, pink-peach sunset glow
    float puffAmt = clamp(CLOUD_PUFFINESS, 0.0, 1.5);
    float warp = valueNoise(p * 0.42) * 0.78;
    float n = cloudFbm(p + vec2(warp, warp * 0.72)); // cloudFbm call #1

    // Second (fine) scale via single valueNoise for rounded cumulus domes
    float billow = valueNoise(p * 3.2 + vec2(warp * 1.3, -warp * 0.9));
    float edgeSoft = mix(0.24, 0.30, rainStrength);
    float clump = smoothstep(1.0 - coverage - 0.03, 1.0 - coverage + edgeSoft, n);
    if (clump <= 0.001) return vec4(0.0, 0.0, 0.0, 1.0);

    // Sculpt soft rounded puffs while keeping blue/lavender gaps between clumps
    float puffMask = clamp(clump + (billow - 0.48) * 0.32 * puffAmt * smoothstep(0.0, 0.45, clump), 0.0, 1.0);
    float dome = pow(max(puffMask, 0.0), 0.78);

    // Safe sun-offset sample for fake self-shadowing (NaN-proof at zenith)
    vec3 lightW = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float xzLen = length(lightW.xz);
    vec2 sunDirXZ = lightW.xz / max(xzLen, 1e-4);
    float stepLen = mix(0.095, 0.048, clamp(abs(lightW.y), 0.0, 1.0)) * smoothstep(0.0, 0.12, xzLen);
    float nSun = cloudFbm(p + sunDirXZ * stepLen + vec2(warp, warp * 0.72)); // cloudFbm call #2

    float shadowGrad = (nSun - n) * (4.8 + 2.2 * puffAmt);
    // Bright sunlit tops/edges, soft shaded undersides on thicker cores
    float lit = clamp(0.76 - shadowGrad - dome * 0.30 * puffAmt + (billow - 0.45) * 0.24 * puffAmt, 0.16, 1.0);
    lit = mix(lit, 0.62, rainStrength * 0.65);

    float h = getSunHeight();
    float sunset = getSunsetFactor(h);
    float mu = dot(dir, lightW);
    float phase = 0.68 + henyeyGreenstein(mu, 0.52) * 0.30;

    // Silver lining around sunlit cloud edges near the sun
    float silverEdge = smoothstep(0.02, 0.38, puffMask) * (1.0 - smoothstep(0.45, 0.96, puffMask));
    float silver = pow(max(mu, 0.0), 7.0) * (0.45 + 0.55 * silverEdge) * (0.55 + 0.45 * puffAmt) * (1.0 - rainStrength * 0.85);

    // Soft grey-lavender shaded underside + bright creamy/pink-peach sunlit tops
    vec3 skyZen = getSkyColor(normalize(upPosition));
    vec3 underside = (getAmbientColor() * 1.15 + skyZen * 0.36) * vec3(0.95, 0.91, 1.06);
    vec3 sunCol = getDirectLightColor();
    vec3 sunsetGlowTint = mix(vec3(1.0), vec3(1.10, 0.84, 0.80), sunset * (0.45 + 0.55 * clamp(0.5 + 0.5 * mu, 0.0, 1.0)));

    vec3 col = underside * (0.62 + 0.38 * lit)
             + sunCol * sunsetGlowTint * (lit * phase * 0.58 + silver * 0.65);

    // Soften into pale grey-lavender overcast layer during snow/rain
    float cl = luminance(col);
    col = mix(col, vec3(cl) * vec3(0.95, 0.93, 1.03), rainStrength * 0.72);

    float fade = exp(-t * 0.00028) * smoothstep(0.015, 0.11, dir.y);
    float a = clamp(dome * 0.90 * fade, 0.0, 0.95);
    return vec4(max(col, 0.0) * a, 1.0 - a);
#else
    float n = cloudFbm(p + vec2(valueNoise(p * 0.4) * 0.9));
    float density = smoothstep(1.0 - coverage, 1.0 - coverage + 0.22, n);
    if (density <= 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

    // fake self-shadowing: thicker cloud toward the sun = darker underside
    vec3 lightW = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float nSun = cloudFbm(p + lightW.xz * 0.06 + vec2(valueNoise(p * 0.4) * 0.9));
    float lit = clamp(1.0 - (nSun - n) * 6.0 - density * 0.35, 0.15, 1.0);

    float mu = dot(dir, lightW);
    float phase = 0.6 + henyeyGreenstein(mu, 0.55) * 0.35;
    vec3 ambient = getAmbientColor() * 1.1 + getSkyColor(normalize(upPosition)) * 0.3;
    vec3 col = ambient * (0.55 + 0.45 * lit) + getDirectLightColor() * lit * phase * 0.55;

    float fade = exp(-t * 0.00030) * smoothstep(0.015, 0.09, dir.y);
    float a = density * 0.92 * fade;
    return vec4(col * a, 1.0 - a);
#endif
#else
    return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

// returns rgb = cloud light, a = how much sky still shows through
vec4 getVolumetricClouds(vec3 viewDir, int steps, float dither) {
#if CLOUD_STYLE == 2 && !defined NETHER && !defined END
    vec3 dir = mat3(gbufferModelViewInverse) * viewDir;
    if (dir.y < 0.015 || cameraPosition.y > CLOUD_BOTTOM) return vec4(0.0, 0.0, 0.0, 1.0);

    float t0 = (CLOUD_BOTTOM - cameraPosition.y) / dir.y;
    float t1 = (CLOUD_TOP - cameraPosition.y) / dir.y;
    if (t0 > 9000.0) return vec4(0.0, 0.0, 0.0, 1.0);
    t1 = min(t1, t0 + 700.0);
    float stepLen = (t1 - t0) / float(steps);

    vec3 lightW = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float mu = dot(dir, lightW);
    float phase = mix(henyeyGreenstein(mu, 0.65), henyeyGreenstein(mu, -0.15), 0.45);

    vec3 sunCol = getDirectLightColor();
    vec3 ambient = getAmbientColor() * 1.3 + getSkyColor(normalize(upPosition)) * 0.35;

    float transmittance = 1.0;
    vec3 light = vec3(0.0);
    for (int i = 0; i < steps; i++) {
        vec3 p = cameraPosition + dir * (t0 + stepLen * (float(i) + dither));
        float d = cloudDensity(p);
        if (d < 0.01) continue;

    #if CLOUD_QUALITY == 2
        float towardLight = cloudDensity(p + lightW * 16.0) + cloudDensity(p + lightW * 42.0) * 0.8;
    #else
        float towardLight = cloudDensity(p + lightW * 28.0) * 1.6;
    #endif
        float sunT = exp(-towardLight * 2.0);
        float powder = 1.0 - exp(-d * 5.0);
        float h = (p.y - CLOUD_BOTTOM) / (CLOUD_TOP - CLOUD_BOTTOM);

        vec3 scatter = sunCol * sunT * phase * mix(0.6, 1.0, powder) + ambient * (0.18 + 0.72 * h);
        float alpha = 1.0 - exp(-d * stepLen * 0.05);
        light += transmittance * alpha * scatter;
        transmittance *= 1.0 - alpha;
        if (transmittance < 0.02) break;
    }

    // far-away clouds melt into the haze near the horizon
    float fade = exp(-t0 * 0.00028) * smoothstep(0.015, 0.09, dir.y);
    return vec4(light * fade, mix(1.0, transmittance, fade));
#else
    return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 getClouds(vec3 viewDir, int steps, float dither) {
#if CLOUD_STYLE == 1
    return getFlatClouds(viewDir);
#elif CLOUD_STYLE == 2
    return getVolumetricClouds(viewDir, steps, dither);
#else
    return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

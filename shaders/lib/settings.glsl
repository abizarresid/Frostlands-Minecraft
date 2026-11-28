// ---------------------------------------------------------------
//  Hearth Shaders - settings
//  Everything here shows up in Video Settings > Shader Packs > Options
// ---------------------------------------------------------------

// Lighting
#define SUN_BRIGHTNESS 1.0      // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]
#define AMBIENT_BRIGHTNESS 1.0  // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]
#define TORCH_BRIGHTNESS 1.0    // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]
#define SHADOW_SOFTNESS 1.0     // [0.5 0.75 1.0 1.5 2.0 3.0]
#define SHADOWS                       // sun shadows: the biggest single cost (the world is drawn a second time)
#define SHADOW_SAMPLES 1        // [1 4 8]
#define WAVING_PLANTS

const int shadowMapResolution = 1024;   // [1024 1536 2048 3072 4096]
const float shadowDistance = 64.0;      // [64.0 80.0 96.0 128.0 160.0 192.0 256.0]
const float sunPathRotation = -30.0;    // [-45.0 -30.0 -15.0 0.0 15.0 30.0 45.0]
const bool shadowHardwareFiltering = true;
const float shadowDistanceRenderMul = 1.0;

// Water
#define WATER_WAVES
#define WATER_WAVE_STRENGTH 0.6 // [0.25 0.4 0.6 0.8 1.0 1.25 1.5 2.0]
#define WATER_REFLECTIONS
#define REAL_WAVES                    // draw the Boats N Waves mod's real waves (the ones boats ride), with whitecaps and surf
#define WAVE_FOAM 0.75          // [0.0 0.5 0.75 1.0 1.25 1.5]
//#define BOAT_WAKES                  // the mod's foam trail and wake ridges behind boats (off: they look fake with Hearth's water)
#define WAVE_QUALITY 0          // [0 1]  0 = Fast (waves worked out per block corner), 1 = Full (every detail per pixel; heavy)
#define WAVE_RANGE 64.0         // [48.0 64.0 96.0 128.0 192.0 256.0]  how far out the big waves are drawn; past this the sea goes calm (much faster)
#define WAVE_DETAIL_DIST 24.0   // [16.0 24.0 40.0 64.0 96.0]  Full quality only: how far out the finest ripples are drawn
//#define WATER_SWELL_ON              // Hearth's own backup swell, only for worlds without the wave mod. OFF in Frostlands: if the
                                      // mod's data dropped out for a frame, this swell dipped the shallows dry for that frame
//#define WATER_HOLE_DEBUG            // paints any spot under the sea level where no water surface was drawn bright magenta
#define WATER_SWELL_HEIGHT 0.35 // [0.15 0.25 0.35 0.5 0.7]
//#define CAUSTICS
#define WATER_CLARITY 1.0       // [0.5 0.75 1.0 1.5 2.0 3.0]
#define WATER_STYLE 3           // [0 1 2 3]  0 = clear, 1 = glacial turquoise, 2 = dark forest lake, 3 = auto (sea dark, mountain lakes glacial)
#define GLACIAL_START 85.0      // [70.0 80.0 85.0 95.0 110.0 130.0]  auto style: water above this height starts turning glacial

// Atmosphere
#define SKY_BRIGHTNESS 1.0      // [0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4]
#define HORIZON_HAZE 1.0        // [0.0 0.5 0.75 1.0]  how much the sky at the horizon blends into the sea haze (hides where the world ends)
#define EDGE_FOG_START 0.70     // [0.35 0.45 0.55 0.65 0.70 0.75 0.85]  where the far edge of the world starts fading into the sky
#define FOG_DENSITY 1.0         // [0.0 0.25 0.5 0.75 1.0 1.5 2.0 3.0]
//#define GODRAYS                     // sun rays (7 samples on every pixel)
#define GODRAY_STRENGTH 0.75    // [0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define CLOUD_STYLE 1           // [0 1 2]  0 = off, 1 = flat (fast), 2 = 3D (slow)
#define CLOUD_COVERAGE 0.55     // [0.2 0.3 0.4 0.45 0.5 0.55 0.6 0.7 0.8]
#define CLOUD_QUALITY 0         // [0 1 2]  3D clouds only: 0 = fast, 1 = balanced, 2 = pretty
#define VALLEY_MIST 1.0         // [0.0 0.25 0.5 0.75 1.0 1.5 2.0]

// Post processing
#define EXPOSURE 1.0            // [0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.6]
#define BLOOM                         // soft glow around bright things (blurs the whole screen every frame)
#define BLOOM_STRENGTH 0.75     // [0.0 0.25 0.5 0.75 1.0 1.5 2.0]
#define SATURATION 0.9          // [0.7 0.8 0.9 1.0 1.05 1.1 1.2 1.3]
#define WARMTH 1.0              // [0.0 0.5 1.0 1.5 2.0]
#define VIGNETTE
#define PNW_GRADE 0.75          // [0.0 0.25 0.5 0.75 1.0 1.25 1.5]
#define WINTER_GRADE 0.6        // [0.0 0.3 0.6 0.8 1.0]  frosty cool shadows and richer Christmas reds

// Look Style & Grading
#define LOOK_STYLE 0            // [0 1 2 3]  0 = Hearth Classic, 1 = PNW Moody, 2 = Clear Winter, 3 = Dreamy
#define EVERGREEN_DEPTH -1.0    // [-1.0 0.0 0.25 0.5 0.75 1.0 1.25 1.5]  Shifts yellow-green foliage toward dark Douglas-fir blue-green (-1 = style default)
#define SHADOW_COOLNESS -1.0    // [-1.0 0.0 0.25 0.5 0.75 1.0 1.25 1.5]  Cool teal/slate (PNW) or frost-blue (Winter) tint in shadows (-1 = style default)
#define BLACK_LIFT -1.0         // [-1.0 0.0 0.008 0.015 0.022 0.032 0.045]  Lifts deepest blacks for a matte filmic toe (-1 = style default)
#define WARM_ACCENT_POP -1.0    // [-1.0 0.0 0.25 0.5 0.75 1.0 1.25 1.5]  Preserves and boosts warm lights, signs, and reds against cold tones (-1 = style default)
#define MOOD_CONTRAST -1.0      // [-1.0 0.0 0.15 0.30 0.45 0.60 0.80]  Filmic S-curve contrast strength (-1 = style default)
#define FOREST_FOG -1.0         // [-1.0 0.0 0.25 0.5 0.75 1.0 1.5 2.0]  Near-ground mist density between trees under low sun/overcast (-1 = style default)
#define MOUNTAIN_CLOUDS -1.0    // [-1.0 0.0 0.5 0.75 1.0 1.25 1.5 2.0]  Thickness of low cloud wisps hugging forested mountainsides (-1 = style default)

// Sky, Time of Day, Night & Moon
#define SUNRISE_STYLE 0         // [0 1 2]  Per-look sunrise mood (0 = default, 1 = rosy / fog pink seam / frosty pink / peach-lilac, 2 = golden dawn / Rainier dawn / deep orange / rose-gold)
#define MORNING_STYLE 0         // [0 1 2]  Per-look morning mood (0 = default, 1 = fresh crisp / marine burn-off / diamond dust / mint-blue, 2 = misty / drizzle grey / pale cold / dewy haze)
#define MIDDAY_STYLE 0          // [0 1 2]  Per-look midday mood (0 = default, 1 = crisp / sun breaks / bluebird / cotton-candy, 2 = overcast / marine grey / ice haze / golden lazy)
#define AFTERNOON_STYLE 0       // [0 1 2]  Per-look afternoon mood (0 = default, 1 = warm golden / forest shafts / golden snow / apricot, 2 = hazy summer / squally / flat white / lavender drift)
#define SUNSET_STYLE 0          // [0 1 2]  Per-look sunset mood (0 = default, 1 = alpenglow / pastel dusk, 2 = golden hour)
#define NIGHT_STYLE 0           // [0 1 2]  Per-look night mood (0 = default, 1 = blue hour / moonlit mist, 2 = dark rainforest / starry clear)
#define DAY_INTENSITY 1.0       // [0.5 0.65 0.8 0.9 1.0 1.1 1.25 1.4 1.5]  Strength of Morning, Midday, and Afternoon mood styles
#define SUNSET_INTENSITY 1.0    // [0.5 0.65 0.8 0.9 1.0 1.1 1.25 1.4 1.5]  Strength of Sunrise and Sunset mood styles
#define ALPENGLOW 1.0           // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]  Pink-coral alpenglow strength on peaks and highlights
#define NIGHT_BRIGHTNESS 1.0    // [0.5 0.65 0.8 0.9 1.0 1.15 1.3 1.5]
#define NIGHT_FOG 1.0           // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]  Night horizon haze & forest fog lift
#define MOON_SIZE 1.0           // [0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define MOON_BRIGHTNESS 1.0     // [0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define MOON_HALO 1.0           // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define STAR_AMOUNT 1.0         // [0.0 0.25 0.5 0.75 1.0 1.5 2.0]
#define PASTEL_AMOUNT 1.0       // [0.0 0.25 0.5 0.75 1.0 1.25 1.5]  Dreamy: strength of pastel lavender/peach sky, fog, and grade
#define SUN_GLOW_SIZE 1.0       // [0.5 0.75 1.0 1.25 1.5 1.75 2.0]  Dreamy: creamy sun disc and soft glow halo size
#define CLOUD_PUFFINESS 1.0     // [0.0 0.25 0.5 0.75 1.0 1.25 1.5]  Dreamy: flat cumulus billow detail, self-shadow, and silver lining

// Surface detail (the crisp "Complementary" look, written for Hearth)
#define GENERATED_NORMALS             // fake bumps from each block texture's own pixels: sunlight picks out texture detail
#define GEN_NORMAL_STRENGTH 1.2 // [0.5 0.8 1.0 1.2 1.5 2.0]
#define COATED_TEXTURES               // a subtle per-texel grain so blocks don't look like flat paint
#define WORLD_OUTLINE                 // soft dark outlines along block edges
#define WORLD_OUTLINE_STRENGTH 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]

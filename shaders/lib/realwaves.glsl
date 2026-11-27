/*
--------------------------------------------------------------------------------

  Realistic Waves for Photon

  Gerstner wave surface driven by the Realistic Waves mod. The mod supplies the
  sea state as rw_* uniforms and the per-column wave field as rw_field
  (r = fetch, g = open sea share, b = depth, a = distance to shore).

  This is a mirror of dev.realwaves.wave.WaveModel / Spectrum in the mod: the
  boats ride the Java version, so keep the two in sync.

  Without the mod, rw_params0.x is 0 and Photon's own water is used unchanged.

--------------------------------------------------------------------------------
*/

#if !defined INCLUDE_REALWAVES
#define INCLUDE_REALWAVES

// The sea state, in WaveUniforms.NAMES order. Iris hands these over as loose uniforms; without a
// shader pack (RW_UBO, the mod's Sodium water shader) they come in one std140 block with a few
// extras that Iris would otherwise provide.
#if defined RW_UBO
#define RW_UNIFORM
layout(std140) uniform rw_Uniforms {
#else
#define RW_UNIFORM uniform
#endif
RW_UNIFORM vec4 rw_params0; // x: enabled, y: wind speed (m/s), z: storm 0-1, w: rain 0-1
RW_UNIFORM vec4 rw_params1; // x: Hs wind sea (open ocean), y: Hs swell, z: wavelength/height, w: choppiness
RW_UNIFORM vec4 rw_cam;     // xy: camera xz mod 1024, z: whitecap readiness 0-1, w: time (s) mod 1000
RW_UNIFORM vec4 rw_wind;    // xy: wind direction, z: wind speed, w: Hs chop (open water)
RW_UNIFORM vec4 rw_windA;   // xy: direction, z: amplitude factor
RW_UNIFORM vec4 rw_windA_p0;
RW_UNIFORM vec4 rw_windA_p1;
RW_UNIFORM vec4 rw_windB;
RW_UNIFORM vec4 rw_windB_p0;
RW_UNIFORM vec4 rw_windB_p1;
RW_UNIFORM vec4 rw_swellA;  // xy: direction, z: amplitude factor, w: wavelength
RW_UNIFORM vec4 rw_swellA_p;
RW_UNIFORM vec4 rw_swellB;
RW_UNIFORM vec4 rw_swellB_p;
RW_UNIFORM vec4 rw_roll;    // xy: roller phases, zw: alongshore variation phases
RW_UNIFORM vec4 rw_windA_c; // chop phases riding on wind system A
RW_UNIFORM vec4 rw_windB_c;
RW_UNIFORM vec4 rw_surf;    // x, z: roller set phases, y: extra swell Hs in the deep open ocean, w: storm set strength
RW_UNIFORM vec4 rw_windA_p2; // phases of wind components 8-9
RW_UNIFORM vec4 rw_windB_p2;
RW_UNIFORM vec4 rw_windA_t; // phases of the ripple twins of wind system A
RW_UNIFORM vec4 rw_windB_t;
RW_UNIFORM vec4 rw_drift;   // xy: gust drift, zw: slick drift (world blocks mod 1024)
RW_UNIFORM vec4 rw_group;   // drift of the wave groups of wind systems A (xy) and B (zw), mod 1024
RW_UNIFORM vec4 rw_group_s; // same for swell systems A and B
RW_UNIFORM vec4 rw_windA_m; // phases of the twins of wind components 4-7 (system A)
RW_UNIFORM vec4 rw_windB_m;
#if defined RW_UBO
	vec4 rw_campos;    // xyz: camera position
	vec4 rw_camfract;  // xyz: fractional part of the camera position
	vec4 rw_still_uv;  // still water sprite in the block atlas: u0, v0, u1, v1
	vec4 rw_flow_uv;   // flowing water sprite
	vec4 rw_sun;       // xyz: direction to the sun (or moon), w: its strength 0-1
	vec4 rw_sky;       // rgb: sky colour overhead, w: daylight 0-1
	vec4 rw_plant_uv[5]; // kelp, kelp stem, seagrass, tall seagrass (bottom, top) sprites
};
#define cameraPosition rw_campos.xyz
#define cameraPositionFract rw_camfract.xyz
#endif

#if defined RW_SAMPLE_FIELD
uniform sampler2D rw_field;
#if !defined RW_UBO
uniform vec3 cameraPositionFract;
#endif
#endif

// Boat wakes (the mod's Wakes.java): r = churned foam, g = wake wave ridges. 2 texels per block over
// the 256 blocks around the camera, world-anchored and wrapped. Not in RW_FAR_ONLY passes (far water
// in composite passes): they draw no wakes, and on macOS they have no texture unit to spare for it.
#if !defined RW_FAR_ONLY
uniform sampler2D rw_wake;
#endif

const float rw_g = 9.81;
const float rw_tau = 6.283185307;
const float rw_hs_to_amp = 0.35355339;
const float rw_chop_swell = 0.35;
const float rw_max_steep = 0.85;
const float rw_field_size = 1024.0;

const float rw_wind_len[10] = float[10](1.40, 2.35, 3.70, 6.10, 9.60, 15.4, 24.8, 39.0, 62.0, 98.0);
const float rw_wind_ang[10] = float[10](1.08, -0.94, 0.77, -0.66, 0.52, -0.44, 0.34, -0.27, 0.18, -0.10);
// Share of each wind-sea component in the geometry (and boat physics); the rest is shading only
const float rw_wind_geom[10] = float[10](0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0);
// Shading-only twins of wind components 0-3 (mirrors Spectrum.TWIN_*)
const float rw_twin_lf[4] = float[4](1.19, 0.86, 1.14, 0.88);
const float rw_twin_ang[4] = float[4](-0.42, 0.45, -0.38, 0.40);
// Geometric twins of wind components 4-7 in light to moderate winds (mirrors Spectrum.MID_TWIN_*)
const float rw_mid_twin_lf[4] = float[4](1.17, 0.87, 1.15, 0.86);
const float rw_mid_twin_ang[4] = float[4](0.38, -0.42, 0.33, -0.36);

// Chop: short, sharp waves crossing at wide angles (mirrors Spectrum.CHOP_*)
const float rw_chop_len[4] = float[4](2.2, 3.1, 4.3, 6.0);
const float rw_chop_ang[4] = float[4](1.05, -0.95, 0.60, -0.50);
const float rw_chop_amp[4] = float[4](0.353, 0.504, 0.605, 0.504);
const float rw_chop_geom[4] = float[4](0.0, 0.0, 0.5, 1.0);
const float rw_chop_sharpness = 1.0;

const float rw_swell_lf[3] = float[3](1.0, 0.78, 1.27);
const float rw_swell_amp[3] = float[3](0.66, 0.58, 0.48);
const float rw_swell_ang[3] = float[3](0.0, 0.20, -0.28);

const float rw_roll_len[2] = float[2](17.0, 10.7);
const float rw_roll_amp[2] = float[2](1.0, 0.35);
const float rw_roll_set = 7.0;
const float rw_roll_set2 = 4.3;
// Wave groups (mirrors Spectrum.GROUP_*)
const float rw_group_wind = 0.55;
const float rw_group_swell = 0.35;

struct RwLocal {
	float hw_eff;
	float hs_eff;
	float hc_eff;
	float lp;
	float breaking;
	float roll_amp;
	float roll_warp;
	float surf;
	float shore;
	vec2 shore_dir;
	float depth;
	float incoming;
	float chop_scale;
	float taper;
	float bank;   // 0-1: the shore here is a high bank (wall, cliff) rather than a beach
};

// Smooth irregular pattern in [-1, 1] over world xz (mirrors Spectrum.organic)
float rw_organic(vec2 w, float a, float b) {
	const float f1 = rw_tau * 23.0 / 1024.0;
	const float f2 = rw_tau * 11.0 / 1024.0;
	const float f3 = rw_tau * 29.0 / 1024.0;
	const float f4 = rw_tau * 13.0 / 1024.0;
	const float f5 = rw_tau * 37.0 / 1024.0;
	return (sin(f1 * w.x + 1.7 * sin(f2 * w.y + a)) + sin(f3 * w.y + 1.3 * sin(f4 * w.x - b)) + 0.6 * sin(f5 * (w.x + w.y) + a + b)) / 2.6;
}

bool rw_active() {
	return rw_params0.x > 0.5;
}

float rw_wind_k(int i) { return rw_tau / rw_wind_len[i]; }

// Uniform phase of wind component i of system sys (0 = A, 1 = B), relative to the camera
float rw_wind_phase(int sys, int i) {
	if (sys == 0) return i < 4 ? rw_windA_p0[i] : (i < 8 ? rw_windA_p1[i - 4] : rw_windA_p2[i - 8]);
	return i < 4 ? rw_windB_p0[i] : (i < 8 ? rw_windB_p1[i - 4] : rw_windB_p2[i - 8]);
}

// Phase noise (mirrors Spectrum.phaseField): three slow fields that bend each component's
// wavefronts so the pattern never tiles. World xz in [0, 1024); whole periods per 1024 blocks.
const float rw_field_n[12] = float[12](7.0, 5.0, 9.0, 4.0, 6.0, 8.0, 5.0, 7.0, 9.0, 4.0, 6.0, 10.0);
const float rw_field_o[6] = float[6](0.3, 1.1, 2.0, 0.4, 1.3, 2.6);
const float rw_phase_noise_max = 2.4;

float rw_phase_field(int f, vec2 w) {
	vec4 n = rw_tau / 1024.0 * vec4(rw_field_n[f * 4], rw_field_n[f * 4 + 1], rw_field_n[f * 4 + 2], rw_field_n[f * 4 + 3]);
	return 0.5 * (sin(n.x * w.x + 1.5 * sin(n.y * w.y + rw_field_o[f * 2])) + sin(n.z * w.y + 1.2 * sin(n.w * w.x + rw_field_o[f * 2 + 1])));
}

// Wave groups (mirrors Spectrum.groupField): slow fields drifting with each wave system that make
// some waves bigger and some smaller. w = world xz minus the system's drift.
const float rw_group_n[12] = float[12](8.0, 6.0, 10.0, 5.0, 7.0, 9.0, 6.0, 8.0, 10.0, 5.0, 7.0, 11.0);
const float rw_group_o[6] = float[6](0.9, 2.2, 1.7, 0.2, 2.8, 1.4);

float rw_group_field(int f, vec2 w) {
	vec4 n = rw_tau / 1024.0 * vec4(rw_group_n[f * 4], rw_group_n[f * 4 + 1], rw_group_n[f * 4 + 2], rw_group_n[f * 4 + 3]);
	return 0.5 * (sin(n.x * w.x + 1.5 * sin(n.y * w.y + rw_group_o[f * 2])) + sin(n.z * w.y + 1.2 * sin(n.w * w.x + rw_group_o[f * 2 + 1])));
}

// Big waves (mirrors Spectrum.rogue): rare drifting hot-spots, 0-1 and mostly 0, where the deep
// ocean's swell grows to more than twice its height. w = world xz minus swell system A's drift.
float rw_rogue(vec2 w) {
	const vec4 n = rw_tau / 1024.0 * vec4(3.0, 2.0, 4.0, 3.0);
	float f = 0.5 * (sin(n.x * w.x + 1.5 * sin(n.y * w.y + 0.7)) + sin(n.z * w.y + 1.2 * sin(n.w * w.x + 1.9)));
	float p = max(f, 0.0);
	p *= p;
	p *= p;
	return p * p;
}

// The sets of a storm sea (mirrors Spectrum.setField): a slow field that scales every wave together
float rw_set_field(vec2 w) {
	float n = rw_tau / 1024.0;
	return 0.5 * (sin(3.0 * n * w.x + 1.3 * sin(2.0 * n * w.y + 0.4)) + sin(2.0 * n * w.y + 1.1 * sin(3.0 * n * w.x + 2.6)));
}

// Height factors (1 + strength * group field) for the three group fields, times the storm's sets
vec3 rw_groups(vec2 w, float strength) {
	float set = 1.0 + rw_surf.w * rw_set_field(w);
	return (1.0 + strength * vec3(rw_group_field(0, w), rw_group_field(1, w), rw_group_field(2, w))) * set;
}

float rw_phase_noise(float len) {
	return min(rw_phase_noise_max, 45.0 / len);
}

// Short-wave warp (mirrors Spectrum.shortWarp): fine fields that stretch and squeeze the spacing of
// waves shorter than 8 blocks and curve their crests. w = world xz in [0, 1024).
vec2 rw_short_warp(int f, vec2 w) {
	const float c = rw_tau / 1024.0;
	vec2 o = f == 0 ? vec2(0.0) : (f == 1 ? vec2(173.0, -91.0) : vec2(-257.0, 311.0));
	vec2 q = w + o;
	return vec2(
		0.5 * sin(c * 53.0 * q.x + 1.4 * sin(c * 37.0 * q.y + 0.7)) + 0.3 * sin(c * 71.0 * q.y + 1.1 * sin(c * 29.0 * q.x + 2.1)) + 0.2 * sin(c * 97.0 * (q.x - q.y) + 0.4),
		0.5 * sin(c * 59.0 * q.y + 1.4 * sin(c * 41.0 * q.x + 1.9)) + 0.3 * sin(c * 67.0 * q.x + 1.1 * sin(c * 31.0 * q.y + 0.3)) + 0.2 * sin(c * 89.0 * (q.x + q.y) + 1.6)
	);
}

float rw_short_warp_amp(float len) {
	return len < 8.0 ? min(0.45 * len, 1.6) : 0.0;
}

vec2 rw_rotate(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

float rw_wind_weight(float len, float lp) {
	float x = log(len / lp);
	return x > 0.0 ? exp(-x * x / 0.18) : exp(1.3 * x);
}

// Wind-sea amplitudes for the local peak wavelength, before the per-system factor
void rw_wind_amps(RwLocal l, out float a[10]) {
	float norm = 0.0;
	for (int i = 0; i < 10; ++i) {
		a[i] = rw_wind_weight(rw_wind_len[i], l.lp);
		norm += a[i] * a[i];
	}
	float scale = l.hw_eff * rw_hs_to_amp * inversesqrt(max(norm, 1e-12));
	for (int i = 0; i < 10; ++i) {
		a[i] *= scale;
	}
}

// Field channels (fetch, open, depth, shore), offshore share and the shore gradient -> local wave parameters
RwLocal rw_local(vec4 f, float offshore, float bank, float rogue, vec2 grad) {
	RwLocal l;
	// Waves run right up to the shore. Where the shore is a wall, cliff or quay with water still deep
	// at its foot they hit it at full height and heave up against it; on a beach they don't.
	float wall = bank * smoothstep(1.5, 5.0, f.b);
	float taper = smoothstep(0.0, mix(2.5, 0.6, wall), f.a);
	float surge = 1.0 + 0.6 * wall * smoothstep(3.0, 0.5, f.a);
	// Waves grow slowly with fetch: lakes and rivers stay small, only the open sea gets big seas
	float hw = rw_params1.x * pow(1.0 - exp(-f.r / 220.0), 1.6);
	float hs = rw_params1.y * pow(clamp(f.g, 0.0, 1.0), 1.5) + rw_surf.y * offshore * (1.0 + 1.4 * rogue);
	float hc = rw_wind.w * pow(1.0 - exp(-f.r / 120.0), 1.3);
	float hinc = sqrt(hw * hw + hs * hs + hc * hc);
	float hmax = mix(0.55, 0.8, smoothstep(6.0, 14.0, f.b)) * f.b + 0.08;
	float lim = hinc > hmax ? hmax / hinc : 1.0;
	float grad_len = length(grad);
	// Rollers need an open approach: none in rivers and canals (short fetch), some on lakes
	float roll = smoothstep(20.0, 3.0, f.a) * smoothstep(8.0, 1.5, f.b) * smoothstep(0.1, 0.4, grad_len)
		* smoothstep(25.0, 90.0, f.r);
	// Shoaling: waves running into shallow water slow down and grow before they break
	float hshoal = hinc * (1.0 + 0.5 * roll);
	float breaking = clamp(hshoal / hmax - 1.0, 0.0, 1.0);
	float open_scale = lim * (1.0 - 0.7 * roll) * taper * surge;

	l.hw_eff = hw * open_scale;
	l.hs_eff = hs * open_scale;
	l.hc_eff = hc * open_scale;
	l.lp = clamp(hw * rw_params1.z, 1.4, 100.0);
	l.breaking = breaking;
	l.roll_amp = min(hshoal, 0.6 * f.b + 0.05) * 0.5 * roll * taper;
	l.shore = f.a;
	l.shore_dir = grad_len > 1e-4 ? -grad / grad_len : vec2(0.0);
	l.depth = f.b;
	l.incoming = hinc;
	l.taper = taper;
	l.roll_warp = 0.0;
	l.surf = 1.0;
	l.bank = bank;

	float a[10];
	rw_wind_amps(l, a);
	float steep = 0.0;
	for (int i = 0; i < 10; ++i) {
		steep += rw_wind_k(i) * a[i] * rw_params1.w * (rw_windA.z + rw_windB.z);
	}
	for (int j = 0; j < 4; ++j) {
		steep += rw_tau / rw_chop_len[j] * l.hc_eff * rw_hs_to_amp * rw_chop_amp[j] * rw_chop_sharpness * (rw_windA.z + rw_windB.z);
	}
	for (int j = 0; j < 3; ++j) {
		float amp = l.hs_eff * rw_hs_to_amp * rw_swell_amp[j] * rw_chop_swell;
		if (rw_swellA.z > 0.0) steep += rw_tau / (rw_swellA.w * rw_swell_lf[j]) * amp * rw_swellA.z;
		if (rw_swellB.z > 0.0) steep += rw_tau / (rw_swellB.w * rw_swell_lf[j]) * amp * rw_swellB.z;
	}
	l.chop_scale = steep > rw_max_steep ? rw_max_steep / steep : 1.0;
	return l;
}

// Pack/unpack for passing the local parameters from the vertex to the fragment shader
void rw_pack(RwLocal l, out vec4 v0, out vec4 v1, out vec4 v2, out vec4 v3) {
	v0 = vec4(l.hw_eff, l.hs_eff, l.lp, l.breaking);
	v1 = vec4(l.roll_amp, l.shore, l.shore_dir);
	v2 = vec4(l.taper, l.depth, l.chop_scale, l.incoming);
	v3 = vec4(l.hc_eff, l.roll_warp, l.surf, l.bank);
}

RwLocal rw_unpack(vec4 v0, vec4 v1, vec4 v2, vec4 v3) {
	RwLocal l;
	l.hw_eff = v0.x;
	l.hs_eff = v0.y;
	l.lp = v0.z;
	l.breaking = v0.w;
	l.roll_amp = v1.x;
	l.shore = v1.y;
	float len = length(v1.zw);
	l.shore_dir = len > 1e-3 ? v1.zw / len : vec2(0.0);
	l.taper = v2.x;
	l.depth = v2.y;
	l.chop_scale = v2.z;
	l.incoming = v2.w;
	l.hc_eff = v3.x;
	l.roll_warp = v3.y;
	l.surf = v3.z;
	l.bank = v3.w;
	return l;
}

// --------------------------------------------------------------------------
//   Surface evaluation at rest position p (camera-relative xz)
//   lag: evaluate this many seconds in the past (for foam trails)
// --------------------------------------------------------------------------

struct RwSurface {
	vec3 offset; // displacement of the surface point
	vec3 normal; // unnormalized surface normal
	float jacobian; // < 1 where the surface bunches up (crests)
	float roller_crest; // 0-1, how close to a roller crest
	float roller_phase;
	float lost_slope2; // slope variance of ripples too fine for the pixel (filtered out)
};

// World-space size of a pixel on the water, set by the fragment shader before rw_eval; 0 = no filtering
float rw_footprint = 0.0;

// How much of a wave of length len a pixel can show without aliasing into moire rings
float rw_aa(float len) {
	return rw_footprint > 0.0 ? smoothstep(2.0, 4.0, len / rw_footprint) : 1.0;
}

void rw_add_wave(
	vec2 p, vec2 dir, float k, float omega, float phase, float amp, float chop, float lag,
	inout RwSurface s, inout vec3 jxx_zz_xz
) {
	float th = k * dot(dir, p) + phase + omega * lag;
	float sn = sin(th);
	float cs = cos(th);
	float qka = chop * k * amp;
	s.offset += vec3(chop * amp * dir.x * cs, amp * sn, chop * amp * dir.y * cs);
	s.normal.x -= dir.x * k * amp * cs;
	s.normal.z -= dir.y * k * amp * cs;
	s.normal.y -= qka * sn;
	jxx_zz_xz += qka * sn * vec3(dir.x * dir.x, dir.y * dir.y, dir.x * dir.y);
}

float rw_hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

// Value noise that tiles every `period` lattice cells. Used on world positions mod 1024 with
// frequencies of n/1024, so patterns have no seam where the field wraps around.
float rw_tiled_noise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 i1 = i + 1.0;
	i = mod(i, period);
	i1 = mod(i1, period);
	float a = rw_hash(i);
	float b = rw_hash(vec2(i1.x, i.y));
	float c = rw_hash(vec2(i.x, i1.y));
	float d = rw_hash(i1);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// world_xz in [0, 1024): noise at n features per 1024 blocks
float rw_world_noise(vec2 world_xz, float n) {
	return rw_tiled_noise(world_xz * (n / rw_field_size), n);
}

// The wake at world xz (any multiple of 1024 off), bilinear
#if defined RW_FAR_ONLY
vec2 rw_wake_at(vec2 world_xz) {
	return vec2(0.0);
}
#else
vec2 rw_wake_at(vec2 world_xz) {
	vec2 t = world_xz * 2.0 - 0.5;
	vec2 i = floor(t);
	vec2 f = t - i;
	ivec2 c0 = ivec2(i) & 511;
	ivec2 c1 = (ivec2(i) + 1) & 511;
	vec2 a = texelFetch(rw_wake, c0, 0).rg;
	vec2 b = texelFetch(rw_wake, ivec2(c1.x, c0.y), 0).rg;
	vec2 c = texelFetch(rw_wake, ivec2(c0.x, c1.y), 0).rg;
	vec2 d = texelFetch(rw_wake, c1, 0).rg;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
#endif

// Whether camera-relative p is inside the wake texture's window
bool rw_in_wake_window(vec2 p) {
	return max(abs(p.x), abs(p.y)) < 124.0;
}

// Micro ripples: fine capillary ripples running in all directions, shading only (they give the
// dense small-scale texture of real water). Wavelengths and directions relative to the wind.
const float rw_micro_len[6] = float[6](0.42, 0.58, 0.77, 0.99, 1.27, 1.63);
const float rw_micro_ang[6] = float[6](2.13, -1.62, 0.91, -0.37, 2.86, -2.31);
const float rw_micro_phase[6] = float[6](0.0, 2.4, 4.1, 1.3, 5.2, 3.3);

// detail = false: only what moves the geometry (matches the boats' physics exactly)
// detail = true: everything, for shading: calm-water ripples broken into glassy slicks and
//                drifting gusty patches ("cat's paws"), patches where different ripple trains
//                take over, short-crested twins of the shortest waves, and micro ripples; ripples
//                finer than the pixel (rw_footprint) are filtered out instead of aliasing
RwSurface rw_eval(vec2 p, RwLocal l, float lag, bool detail) {
	RwSurface s;
	s.offset = vec3(0.0);
	s.normal = vec3(0.0, 1.0, 0.0);
	s.roller_crest = 0.0;
	s.roller_phase = 0.0;
	s.lost_slope2 = 0.0;
	vec3 jac = vec3(0.0);

	float chop_w = rw_params1.w * l.chop_scale;
	float chop_s = rw_chop_swell * l.chop_scale;
	float chop_c = rw_chop_sharpness * l.chop_scale;

	float a[10];
	rw_wind_amps(l, a);

	// Phase noise fields at this point (world position mod 1024)
	vec2 world_xz = p + rw_cam.xy;
	float fields[3] = float[3](rw_phase_field(0, world_xz), rw_phase_field(1, world_xz), rw_phase_field(2, world_xz));
	vec2 sw[3] = vec2[3](rw_short_warp(0, world_xz), rw_short_warp(1, world_xz), rw_short_warp(2, world_xz));

	float short_scale = 1.0;
	vec2 p_short = p;
	float calm = 1.0 - smoothstep(4.0, 12.0, rw_params0.y);
	// Everything short of a storm: storms keep their look
	float mild = 1.0 - smoothstep(10.0, 17.0, rw_params0.y);
	vec3 patches = vec3(1.0);
	// Share of the medium components' height in their twins (mirrors Spectrum.midTwinShare)
	float mid_twin = 0.6 * mild;
	float mid_main = sqrt(1.0 - mid_twin * mid_twin);
	if (detail) {
		p_short += 2.5 * vec2(rw_world_noise(world_xz, 61.0), rw_world_noise(world_xz + 311.0, 61.0)) - 1.25;
		if (calm > 0.0) {
			// A calm sea is glassy slicks between rippled patches, with gusty cat's paws drifting downwind
			vec2 warp = vec2(rw_world_noise(world_xz, 9.0), rw_world_noise(world_xz + 517.0, 9.0)) - 0.5;
			vec2 slick_xz = world_xz - rw_drift.zw + 110.0 * warp;
			float slick = smoothstep(0.36, 0.56, 0.65 * rw_world_noise(slick_xz, 11.0) + 0.35 * rw_world_noise(slick_xz, 29.0));
			float gust = smoothstep(0.25, 0.8, rw_world_noise(world_xz - rw_drift.xy, 36.0));
			short_scale = mix(1.0, mix(0.04, 1.0, slick) * (0.2 + 1.1 * gust), calm);
		}
		if (mild > 0.0) {
			// Patches where different ripple trains take over, so no one pattern runs across the sea
			vec2 patch_xz = world_xz - rw_drift.zw;
			vec3 n = vec3(rw_world_noise(patch_xz, 23.0), rw_world_noise(patch_xz + 401.0, 37.0), rw_world_noise(patch_xz + 803.0, 53.0));
			patches = mix(vec3(1.0), 0.15 + 1.7 * smoothstep(vec3(0.2), vec3(0.8), n), mild);
		}
	}

	for (int sys = 0; sys < 2; ++sys) {
		vec4 dir_amp = sys == 0 ? rw_windA : rw_windB;
		if (dir_amp.z <= 0.0) continue;
		// Wave groups: bigger here, smaller there (no sharper: the Gerstner choppiness eases off)
		vec3 grp = rw_groups(world_xz - (sys == 0 ? rw_group.xy : rw_group.zw), rw_group_wind);

		// Wind sea
		for (int i = 0; i < 10; ++i) {
			float weight = detail ? (i < 3 ? short_scale * (i == 1 ? 2.0 - patches[1] : patches[i]) : 1.0) : rw_wind_geom[i];
			float m = grp[i % 3];
			int twin = i - 4;
			bool has_twin = twin >= 0 && twin < 4 && mid_twin > 0.0;
			float amp = a[i] * dir_amp.z * weight * m * (has_twin ? mid_main : 1.0);
			float q_w = chop_w / max(m, 1.0);
			if (amp < 1e-5) continue;
			if (has_twin) {
				// The medium component's twin: a little longer or shorter and turned (mirrors WaveModel.eval)
				float amp_m = a[i] * dir_amp.z * weight * m * mid_twin;
				float len_m = rw_wind_len[i] * rw_mid_twin_lf[twin];
				float k_m = rw_tau / len_m;
				float phase_m = (sys == 0 ? rw_windA_m[twin] : rw_windB_m[twin]) + rw_phase_noise(len_m) * fields[(i + 1) % 3];
				rw_add_wave(p, rw_rotate(dir_amp.xy, rw_wind_ang[i] + rw_mid_twin_ang[twin]), k_m, sqrt(rw_g * k_m), phase_m, amp_m, q_w, lag, s, jac);
			}
			float k = rw_wind_k(i);
			if (detail) {
				float aa = mix(1.0, rw_aa(rw_wind_len[i]), mild);
				s.lost_slope2 += 0.5 * (1.0 - aa * aa) * k * k * amp * amp;
				amp *= aa;
				if (amp < 1e-5) continue;
			}
			float phase = rw_wind_phase(sys, i) + rw_phase_noise(rw_wind_len[i]) * fields[i % 3];
			vec2 q = p + rw_short_warp_amp(rw_wind_len[i]) * sw[i % 3] + (i < 2 ? p_short - p : vec2(0.0));
			rw_add_wave(q, rw_rotate(dir_amp.xy, rw_wind_ang[i]), k, sqrt(rw_g * k), phase, amp, q_w, lag, s, jac);

			// Its twin, slightly longer or shorter and turned: the two beat into short, uneven crests
			if (detail && i < 4 && mild > 0.0) {
				float len_t = rw_wind_len[i] * rw_twin_lf[i];
				float k_t = rw_tau / len_t;
				float amp_t = a[i] * dir_amp.z * 0.6 * mild * (i < 3 ? short_scale : 1.0) * (2.0 - patches[(i + 2) % 3]) * rw_aa(len_t) * m;
				if (amp_t < 1e-5) continue;
				float phase_t = (sys == 0 ? rw_windA_t[i] : rw_windB_t[i]) + rw_phase_noise(len_t) * fields[(i + 1) % 3];
				vec2 q_t = p + rw_short_warp_amp(len_t) * sw[(i + 1) % 3] + (i < 2 ? p_short - p : vec2(0.0));
				rw_add_wave(q_t, rw_rotate(dir_amp.xy, rw_wind_ang[i] + rw_twin_ang[i]), k_t, sqrt(rw_g * k_t), phase_t, amp_t, q_w, lag, s, jac);
			}
		}

		// Chop: short, sharp waves riding on the wind sea
		if (l.hc_eff > 1e-5) {
			for (int j = 0; j < 4; ++j) {
				float weight = detail ? (j < 2 ? patches[(j + 1) % 3] : 1.0) : rw_chop_geom[j];
				float m = grp[(j + 1) % 3];
				float amp = l.hc_eff * rw_hs_to_amp * rw_chop_amp[j] * weight * dir_amp.z * m;
				float q_c = chop_c / max(m, 1.0);
				if (amp < 1e-5) continue;
				float k = rw_tau / rw_chop_len[j];
				if (detail) {
					float aa = mix(1.0, rw_aa(rw_chop_len[j]), mild);
					s.lost_slope2 += 0.5 * (1.0 - aa * aa) * k * k * amp * amp;
					amp *= aa;
					if (amp < 1e-5) continue;
				}
				float phase = (sys == 0 ? rw_windA_c[j] : rw_windB_c[j]) + rw_phase_noise_max * fields[(j + 1) % 3];
				vec2 q = p + rw_short_warp_amp(rw_chop_len[j]) * sw[(j + 1) % 3] + (j < 2 ? p_short - p : vec2(0.0));
				rw_add_wave(q, rw_rotate(dir_amp.xy, rw_chop_ang[j]), k, sqrt(rw_g * k), phase, amp, q_c, lag, s, jac);
			}
		}
	}

	// Swell
	if (l.hs_eff > 1e-5) {
		for (int sys = 0; sys < 2; ++sys) {
			vec4 dir_amp_len = sys == 0 ? rw_swellA : rw_swellB;
			vec4 phases = sys == 0 ? rw_swellA_p : rw_swellB_p;
			if (dir_amp_len.z <= 0.0) continue;
			vec3 grp = rw_groups(world_xz - (sys == 0 ? rw_group_s.xy : rw_group_s.zw), rw_group_swell);
			for (int j = 0; j < 3; ++j) {
				float m = grp[(j + 2) % 3];
				float amp = l.hs_eff * rw_hs_to_amp * rw_swell_amp[j] * dir_amp_len.z * m;
				float len = dir_amp_len.w * rw_swell_lf[j];
				float k = rw_tau / len;
				float phase = phases[j] + rw_phase_noise(len) * fields[(j + 2) % 3];
				rw_add_wave(p, rw_rotate(dir_amp_len.xy, rw_swell_ang[j]), k, sqrt(rw_g * k), phase, amp, chop_s / max(m, 1.0), lag, s, jac);
			}
		}
	}

	// Micro ripples (shading only): steeper in wind, patchy in a calm
	if (detail) {
		float wind_ripple = mix(0.012, 0.05, smoothstep(2.0, 12.0, rw_params0.y)) * l.taper;
		wind_ripple *= mix(1.0, short_scale, calm);
		float t = rw_cam.w - lag;
		for (int m = 0; m < 6; ++m) {
			float k = rw_tau / rw_micro_len[m];
			float slope = wind_ripple * (m % 2 == 0 ? patches[m % 3] : 2.0 - patches[m % 3]);
			float aa = mix(1.0, rw_aa(rw_micro_len[m]), mild);
			s.lost_slope2 += 0.5 * (1.0 - aa * aa) * slope * slope;
			float amp = slope * aa / k;
			vec2 dir = rw_rotate(rw_wind.xy, rw_micro_ang[m]);
			float th = k * dot(dir, p_short + 0.6 * sw[m % 3] + rw_cam.xy) + rw_micro_phase[m] - sqrt(rw_g * k) * t + 2.0 * fields[m % 3];
			float cs = cos(th);
			s.normal.x -= dir.x * k * amp * cs;
			s.normal.z -= dir.y * k * amp * cs;
		}
	}

	// Rollers: shore-bound waves, steepening and pitching forward as they break
	if (l.roll_amp > 1e-5) {
		for (int r = 0; r < 2; ++r) {
			float ar = l.roll_amp * rw_roll_amp[r];
			float k = rw_tau / rw_roll_len[r];
			float omega = sqrt(rw_g * k * tanh(k * 3.0));
			float th = k * l.shore + rw_roll[r] + l.roll_warp - omega * lag;
			float pw = r == 0 ? 2.0 + 2.0 * l.breaking : 2.0;
			// Hearth: cos() can round to just under -1, making c a hair negative, and pow(negative, 2.5) is NaN.
			// A NaN corner drops every triangle around it: the hexagonal holes at the shoreline.
			float c = max(0.5 + 0.5 * cos(th), 0.0);
			float f = pow(c, pw);
			float m = 0.375 - 0.051 * (pw - 2.0);
			float h = 2.0 * ar * (f - m);
			float lean = (0.35 + 0.6 * l.breaking) * h;
			s.offset += vec3(l.shore_dir.x * lean, h, l.shore_dir.y * lean);
			// d(shore)/dxz = -shore_dir, so dh/dxz = -2 ar f'(th) k shore_dir
			float df = pw * pow(max(c, 1e-4), pw - 1.0) * (-0.5 * sin(th));
			vec2 dh = -2.0 * ar * df * k * l.shore_dir;
			s.normal.xz -= dh;
			if (r == 0) {
				s.roller_crest = pow(c, 8.0);
				s.roller_phase = th;
			}
		}
	}

	// Boat wakes: the V of wake waves behind boats (shading only)
	if (detail && rw_in_wake_window(p)) {
		vec2 w = p + rw_cam.xy;
		if (rw_wake_at(w).g > 0.0) {
			float hx = rw_wake_at(w + vec2(0.5, 0.0)).g - rw_wake_at(w - vec2(0.5, 0.0)).g;
			float hz = rw_wake_at(w + vec2(0.0, 0.5)).g - rw_wake_at(w - vec2(0.0, 0.5)).g;
			s.normal.xz -= 0.3 * vec2(hx, hz);
		}
	}

	// Swash: on a beach each wave runs up onto the sand and slides back (mirrors WaveModel.eval)
	float swash = smoothstep(2.2, 0.4, l.shore) * (1.0 - l.bank * smoothstep(1.5, 5.0, l.depth)) * smoothstep(0.05, 0.3, l.incoming);
	if (swash > 0.0) {
		float run = min(0.35 + 0.9 * l.incoming, 1.6) * mix(0.6, 1.0, smoothstep(0.15, 0.7, l.surf));
		float th = rw_tau / rw_roll_len[0] * l.shore + rw_roll.x + l.roll_warp - 0.5;
		float up = pow(max(0.5 + 0.5 * cos(th), 0.0), 2.5) * run * swash;   // Hearth: max() keeps pow() off negatives (NaN)
		// The sheet of water slides over the sand, just covering it
		s.offset += vec3(l.shore_dir.x * up, min(0.25 * up, 0.24), l.shore_dir.y * up);
	}

	s.jacobian = (1.0 - jac.x) * (1.0 - jac.y) - jac.z * jac.z;
	// Hearth: never hand back NaN/inf (written as comparisons too, which survive fast-math compilers)
	bool bad = any(isnan(s.offset)) || any(isinf(s.offset)) || any(isnan(s.normal))
	        || !(abs(s.offset.x) < 64.0 && abs(s.offset.y) < 64.0 && abs(s.offset.z) < 64.0)
	        || !(abs(s.normal.x) < 1e4 && abs(s.normal.y) < 1e4 && abs(s.normal.z) < 1e4);
	if (bad) { s.offset = vec3(0.0); s.normal = vec3(0.0, 1.0, 0.0); }
	return s;
}

// --------------------------------------------------------------------------
//   Far water (Distant Horizons): a lightweight look-alike, shading only
// --------------------------------------------------------------------------

// The open sea's surface normal far out, where there is no wave field: the swell and the long
// wind-sea components with the same phases as the full waves (so they line up where the full waves
// end), open-ocean heights, no groups, warps or chop. Components too short for the distance fade
// out instead of shimmering. p = camera-relative xz. `crest` is how high the wind sea stands here
// against its usual range, about -1 (trough) to 1 (crest), for rw_far_whitecaps.
vec3 rw_far_surface(vec2 p, float dist, out float crest) {
	vec3 n = vec3(0.0, 1.0, 0.0);
	crest = 0.0;
	if (!rw_active()) return n;
	float eta = 0.0;
	float range = 1e-4;
	RwLocal l;
	l.hw_eff = rw_params1.x;
	l.lp = clamp(rw_params1.x * rw_params1.z, 1.4, 100.0);
	float a[10];
	rw_wind_amps(l, a);
	float chop = rw_params1.w;
	for (int sys = 0; sys < 2; ++sys) {
		vec4 dir_amp = sys == 0 ? rw_windA : rw_windB;
		if (dir_amp.z <= 0.0) continue;
		for (int i = 4; i < 10; ++i) {
			float amp = a[i] * dir_amp.z * smoothstep(dist * 0.01, dist * 0.03, rw_wind_len[i]);
			if (amp < 1e-3) continue;
			float k = rw_wind_k(i);
			vec2 dir = rw_rotate(dir_amp.xy, rw_wind_ang[i]);
			float th = k * dot(dir, p) + rw_wind_phase(sys, i);
			float ka = k * amp * cos(th);
			n.xz -= dir * ka;
			n.y -= chop * k * amp * sin(th);
			eta += amp * sin(th);
			range += amp;
		}
	}
	crest = eta / (0.5 * range);
	// Swell: open-sea swell plus about half the deep-ocean extra
	float hs = rw_params1.y + 0.5 * rw_surf.y;
	for (int sys = 0; sys < 2; ++sys) {
		vec4 dir_amp_len = sys == 0 ? rw_swellA : rw_swellB;
		vec4 phases = sys == 0 ? rw_swellA_p : rw_swellB_p;
		if (dir_amp_len.z <= 0.0) continue;
		for (int j = 0; j < 3; ++j) {
			float amp = hs * rw_hs_to_amp * rw_swell_amp[j] * dir_amp_len.z;
			float k = rw_tau / (dir_amp_len.w * rw_swell_lf[j]);
			vec2 dir = rw_rotate(dir_amp_len.xy, rw_swell_ang[j]);
			n.xz -= dir * k * amp * cos(k * dot(dir, p) + phases[j]);
		}
	}
	return normalize(n);
}

vec3 rw_far_normal(vec2 p, float dist) {
	float crest;
	return rw_far_surface(p, dist, crest);
}

// 0-1: whitecaps far out in a blow, no crest tracking but on the far waves' crests (`crest` from
// rw_far_surface). Small caps a couple of blocks across, under 1% of the sea in a fresh breeze and
// about 5% in a gale, bunched where the wave groups are. They form and fade as two layers drift
// past each other. Past a couple of hundred blocks, where single caps would only shimmer, they
// blend into their average: a faint whitening along the crests. p = camera-relative xz.
float rw_far_whitecaps(vec2 p, float dist, float crest) {
	float readiness = rw_cam.z;
	if (readiness < 0.05 || !rw_active()) return 0.0;
	vec2 w = p + rw_cam.xy - rw_group.xy;
	float bunch = smoothstep(0.25, 0.75, rw_world_noise(w, 10.0));
	float on_crest = smoothstep(0.0, 0.8, crest);
	float cover = readiness * (0.008 + 0.045 * rw_params0.z) * (0.3 + 1.4 * bunch) * 3.0 * on_crest;
	cover = clamp(cover, 0.0, 0.4);   // Hearth: never negative (pow below)
	float far = smoothstep(120.0, 400.0, dist);
	float caps = 0.0;
	if (far < 1.0 && cover > 1e-3) {
		float n = 0.7 * rw_world_noise(w, 400.0) + 0.3 * rw_world_noise(p + rw_cam.xy - rw_drift.xy, 800.0);
		// The noise is close to normal with sd 0.16: the threshold that leaves `cover` above it
		float t = 0.5 + 0.785 * (pow(1.0 - cover, 0.14) - pow(cover, 0.14));
		caps = smoothstep(t - 0.025, t + 0.025, n);
	}
	return mix(0.8 * caps, 0.5 * cover, far);
}

// --------------------------------------------------------------------------
//   Vertex side: sample the field and displace
// --------------------------------------------------------------------------

#if defined RW_SAMPLE_FIELD
// One column's (fetch, open, depth, shore) and (offshore share, high bank) for the water surface at
// `level`, or zeros if it has none there. The field holds two surfaces per column (rows 0-1023 and
// 1024-2047), so water under a floating island and the island's own pool each find their own data.
vec4 rw_column(ivec2 col, float level, out vec2 extra) {
	ivec2 c = col & 1023;
	extra = vec2(0.0);
	for (int layer = 0; layer < 2; ++layer) {
		vec4 t = texelFetch(rw_field, ivec2(c.x, c.y + layer * 1024), 0);
		float s = floor(t.g + 0.001);
		if (t.a > 0.0 && abs(s - level) <= 1.0) {
			// Depth is whole blocks; the fraction carries the offshore share (FieldTile.OFFSHORE_IN_DEPTH).
			// The level's fraction is (open share + bank level 0-2) / 4.
			float d = floor(t.b);
			float q = (t.g - s) * 4.0;
			float bank_level = floor(q + 1e-4);
			extra = vec2((t.b - d) / 0.9, 0.5 * bank_level);
			return vec4(t.r, max(q - bank_level, 0.0), d, t.a);
		}
	}
	return vec4(0.0);
}

vec4 rw_column(ivec2 col, float level) {
	vec2 extra;
	return rw_column(col, level, extra);
}

// Local wave parameters at a water vertex (a block corner) for the surface at `level`; false if
// there are no waves here. Mirrors WaveField.sample: bilinear over column centres = the average
// of the four columns around the corner.
float rw_min_depth = 1e4;   // Hearth: set by rw_local_at

bool rw_local_at(vec3 scene_pos, float level, out RwLocal l) {
	l = rw_local(vec4(0.0), 0.0, 0.0, 0.0, vec2(0.0));
	// rw_cam.xy is the camera position mod 1024 in double precision, so this is the corner's
	// world column index mod 1024, exact at any distance from the origin
	ivec2 corner = ivec2(floor(scene_pos.xz + rw_cam.xy + 0.5));
	vec2 e11, e21, e12, e22;
	vec4 c11 = rw_column(corner + ivec2(-1, -1), level, e11);
	vec4 c21 = rw_column(corner + ivec2(0, -1), level, e21);
	vec4 c12 = rw_column(corner + ivec2(-1, 0), level, e12);
	vec4 c22 = rw_column(corner + ivec2(0, 0), level, e22);
	vec4 f = 0.25 * (c11 + c21 + c12 + c22);
	vec2 extra = 0.25 * (e11 + e21 + e12 + e22);
	if (f.a < 0.01) return false;

	// Shore distance at the neighbouring corners, for its gradient
	float a01 = rw_column(corner + ivec2(-1, -2), level).a;
	float a02 = rw_column(corner + ivec2(0, -2), level).a;
	float a10 = rw_column(corner + ivec2(-2, -1), level).a;
	float a13 = rw_column(corner + ivec2(1, -1), level).a;
	float a20 = rw_column(corner + ivec2(-2, 0), level).a;
	float a23 = rw_column(corner + ivec2(1, 0), level).a;
	float a31 = rw_column(corner + ivec2(-1, 1), level).a;
	float a32 = rw_column(corner + ivec2(0, 1), level).a;
	float sx1 = 0.25 * (c21.a + a13 + c22.a + a23);
	float sx0 = 0.25 * (a10 + c11.a + a20 + c12.a);
	float sz1 = 0.25 * (c12.a + c22.a + a31 + a32);
	float sz0 = 0.25 * (a01 + a02 + c11.a + c21.a);
	float rogue = rw_rogue(scene_pos.xz + rw_cam.xy - rw_group_s.xy);
	l = rw_local(f, extra.x, extra.y, rogue, 0.5 * vec2(sx1 - sx0, sz1 - sz0));
	rw_min_depth = min(min(c11.b, c21.b), min(c12.b, c22.b));   // Hearth: the shallowest of the 4 columns (l.depth is their average)

	// Uneven surf: peaks and flat sections along the shore, sets of bigger rollers with lulls
	// between, and bent crests (mirrors WaveModel.local)
	vec2 world_xz = scene_pos.xz + rw_cam.xy;
	float sections = clamp(0.7 + 0.6 * rw_organic(world_xz, rw_roll.z, rw_roll.w), 0.15, 1.3);
	float sets = 0.55 + 0.25 * sin(rw_tau / rw_roll_len[0] * l.shore / rw_roll_set + rw_surf.x)
		+ 0.2 * sin(rw_tau / rw_roll_len[0] * l.shore / rw_roll_set2 + rw_surf.z);
	l.surf = sections * sets;
	l.roll_amp *= l.surf;
	l.breaking *= smoothstep(0.15, 0.6, l.surf);
	l.roll_warp = 1.6 * rw_organic(vec2(world_xz.y + 300.0, world_xz.x - 200.0), rw_roll.w, rw_roll.z);

	// Fade out toward the edge of the field (1024 blocks across, centred on the camera)
	float fade = smoothstep(500.0, 440.0, length(scene_pos.xz));
	l.hw_eff *= fade;
	l.hs_eff *= fade;
	l.hc_eff *= fade;
	l.roll_amp *= fade;
	l.taper *= fade;
	return l.taper > 0.0;
}

// True for vertices on the top of still water: the source block surface sits 8/9 up
// the block (minus the renderer's 0.001 offset)
bool rw_is_surface_vertex(vec3 scene_pos) {
	float frac_y = fract(scene_pos.y + cameraPositionFract.y);
	return abs(frac_y - 0.8879) < 0.006;
}

// Water plants (kelp, seagrass) left sticking out of a wave trough: pulls the vertex down under the
// surface. Only in columns with a water surface just above, so land plants are left alone.
// Hearth: how far a trough may pull the water surface DOWN here. The field's depth is a 4-column average and runs
// deep right at the shore, so keep a 1.6-block margin above the floor and calm the troughs within ~4 blocks of the
// shoreline. Otherwise the surface drops under the sand for a moment and a dry patch of sea floor flashes into view.
float rw_max_down(RwLocal l) {
	// rest surface is 0.111 under the top of the water; keep another 0.25 above the floor of the SHALLOWEST column
	// none at all over the shallow shelf (any neighbouring column 2 blocks deep or less), then easing in
	return max(0.0, rw_min_depth - 0.36) * smoothstep(0.5, 2.5, l.shore) * smoothstep(2.5, 4.0, rw_min_depth);
}

// Hearth: in shallow water near the shore, waves mustn't slide the surface sideways over a raised step of sand
float rw_side_damp(RwLocal l) {
	return smoothstep(0.5, 2.5, l.shore) * smoothstep(1.0, 2.5, rw_min_depth);
}

vec3 rw_keep_under(vec3 scene_pos) {
	if (!rw_active()) return scene_pos;
	ivec2 col = ivec2(floor(scene_pos.xz + rw_cam.xy)) & 1023;
	float y = scene_pos.y + cameraPosition.y;
	float level = -10000.0;
	for (int layer = 0; layer < 2; ++layer) {
		vec4 t = texelFetch(rw_field, ivec2(col.x, col.y + layer * 1024), 0);
		float s = floor(t.g + 0.001);
		// A water plant's tip is at most a block above the top water block
		if (t.a > 0.0 && y > s - 6.0 && y < s + 1.2) level = s;
	}
	RwLocal l;
	if (level < -1000.0 || !rw_local_at(scene_pos, level, l)) return scene_pos;
	// The surface height above this point (one Lagrangian step: the water there came from upwave).
	// The drawn surface is faceted (a vertex per block), so keep well under it in bigger waves.
	vec3 o = rw_eval(scene_pos.xz, l, 0.0, false).offset;
	o = rw_eval(scene_pos.xz - o.xz, l, 0.0, false).offset;
	o.y = max(o.y, -rw_max_down(l));      // Hearth: same limit as the drawn surface
	float surface = level + 0.8889 + o.y - cameraPosition.y;
	scene_pos.y = min(scene_pos.y, surface - 0.15 - 0.35 * min(l.incoming, 2.0));
	return scene_pos;
}

// Displaces a water vertex; fills l and returns true if it is on a wave surface
bool rw_displace(inout vec3 scene_pos, out RwLocal l) {
	l = rw_local(vec4(0.0), 0.0, 0.0, 0.0, vec2(0.0));
	if (!rw_active() || !rw_is_surface_vertex(scene_pos)) return false;
	float level = floor(scene_pos.y + cameraPosition.y);
	if (!rw_local_at(scene_pos, level, l)) return false;

	// Waves shorter than ~4 blocks can't be resolved by 1-block geometry: they only go into
	// the per-pixel normals (detail = false leaves them out)
	vec3 off = rw_eval(scene_pos.xz, l, 0.0, false).offset;
	off.y = max(off.y, -rw_max_down(l));   // Hearth: troughs stay clear of the sea floor in shallow water
	off.xz *= rw_side_damp(l);
	scene_pos += off;
	return true;
}
#endif

// --------------------------------------------------------------------------
//   Fragment side: normal and foam
// --------------------------------------------------------------------------

// Bubbly foam texture, world-anchored
float rw_foam_texture(vec2 world_xz) {
	return 0.6 * rw_world_noise(world_xz, 1740.0) + 0.4 * rw_world_noise(world_xz, 4400.0);
}

// The waves `lag` seconds ago, cheaply, for foam that lingers where it formed: x = crest bunching
// (the Jacobian) of the waves that whitecap, y = height of the big waves (wind sea and swell)
vec2 rw_crest_state(vec2 p, RwLocal l, float lag) {
	float a[10];
	rw_wind_amps(l, a);
	float chop_w = rw_params1.w * l.chop_scale;
	float chop_c = rw_chop_sharpness * l.chop_scale;
	vec2 world_xz = p + rw_cam.xy;
	float fields[3] = float[3](rw_phase_field(0, world_xz), rw_phase_field(1, world_xz), rw_phase_field(2, world_xz));
	vec2 sw[3] = vec2[3](rw_short_warp(0, world_xz), rw_short_warp(1, world_xz), rw_short_warp(2, world_xz));
	vec3 jac = vec3(0.0);
	float height = 0.0;
	for (int sys = 0; sys < 2; ++sys) {
		vec4 dir_amp = sys == 0 ? rw_windA : rw_windB;
		if (dir_amp.z <= 0.0) continue;
		vec3 grp = rw_groups(world_xz - (sys == 0 ? rw_group.xy : rw_group.zw), rw_group_wind);
		for (int i = 3; i < 10; ++i) {
			float m = grp[i % 3];
			float amp = a[i] * dir_amp.z * m;
			if (amp < 1e-4) continue;
			float k = rw_wind_k(i);
			vec2 dir = rw_rotate(dir_amp.xy, rw_wind_ang[i]);
			float phase = rw_wind_phase(sys, i) + rw_phase_noise(rw_wind_len[i]) * fields[i % 3];
			vec2 q = p + rw_short_warp_amp(rw_wind_len[i]) * sw[i % 3];
			float sn = sin(k * dot(dir, q) + phase + sqrt(rw_g * k) * lag);
			jac += chop_w / max(m, 1.0) * k * amp * sn * vec3(dir.x * dir.x, dir.y * dir.y, dir.x * dir.y);
			height += amp * sn;
		}
		if (l.hc_eff > 1e-4) {
			for (int j = 1; j < 4; ++j) {
				float m = grp[(j + 1) % 3];
				float amp = l.hc_eff * rw_hs_to_amp * rw_chop_amp[j] * dir_amp.z * m;
				float k = rw_tau / rw_chop_len[j];
				vec2 dir = rw_rotate(dir_amp.xy, rw_chop_ang[j]);
				float phase = (sys == 0 ? rw_windA_c[j] : rw_windB_c[j]) + rw_phase_noise_max * fields[(j + 1) % 3];
				vec2 q = p + rw_short_warp_amp(rw_chop_len[j]) * sw[(j + 1) % 3];
				float sn = sin(k * dot(dir, q) + phase + sqrt(rw_g * k) * lag);
				jac += chop_c / max(m, 1.0) * k * amp * sn * vec3(dir.x * dir.x, dir.y * dir.y, dir.x * dir.y);
			}
		}
	}
	if (l.hs_eff > 1e-4) {
		for (int sys = 0; sys < 2; ++sys) {
			vec4 dir_amp_len = sys == 0 ? rw_swellA : rw_swellB;
			vec4 phases = sys == 0 ? rw_swellA_p : rw_swellB_p;
			if (dir_amp_len.z <= 0.0) continue;
			vec3 grp = rw_groups(world_xz - (sys == 0 ? rw_group_s.xy : rw_group_s.zw), rw_group_swell);
			for (int j = 0; j < 3; ++j) {
				float amp = l.hs_eff * rw_hs_to_amp * rw_swell_amp[j] * dir_amp_len.z * grp[(j + 2) % 3];
				float len = dir_amp_len.w * rw_swell_lf[j];
				float k = rw_tau / len;
				float phase = phases[j] + rw_phase_noise(len) * fields[(j + 2) % 3];
				height += amp * sin(k * dot(rw_rotate(dir_amp_len.xy, rw_swell_ang[j]), p) + phase + sqrt(rw_g * k) * lag);
			}
		}
	}
	return vec2((1.0 - jac.x) * (1.0 - jac.y) - jac.z * jac.z, height);
}

// 0-1: how churned up and sandy the water is (breaking waves over a shallow bottom)
float rw_turbidity(RwLocal l) {
	return smoothstep(0.05, 0.4, l.roll_amp) * (0.4 + 0.6 * l.breaking) * smoothstep(8.0, 2.0, l.depth) * l.taper;
}

// Foam coverage 0-1 at rest position p: whitecaps, breaking rollers and shore wash
float rw_foam(vec2 p, RwLocal l, RwSurface s) {
	vec2 world_xz = mod(p + rw_cam.xy, rw_field_size);
	vec2 wind = rw_wind.xy;

	// Whitecaps where crests bunch up and steepen. Not every crest breaks: breaking happens in
	// patches (gusts, wave groups) that drift downwind, and the foam lingers where it formed.
	float readiness = rw_cam.z;
	float size_ok = smoothstep(0.08, 0.5, l.hw_eff + 0.5 * l.hs_eff + 0.8 * l.hc_eff);
	float caps = 0.0;
	if (readiness * size_ok > 0.01) {
		vec2 drifted = mod(world_xz - wind * rw_cam.w * 1.2, rw_field_size);
		float groups = 0.65 * rw_world_noise(drifted, 72.0) + 0.35 * rw_world_noise(drifted, 190.0);
		float storm = rw_params0.z;
		float breaking_here = smoothstep(mix(0.72, 0.46, readiness) - 0.1 * storm, mix(0.9, 0.68, readiness) - 0.1 * storm, groups);
		if (breaking_here > 0.0) {
			float thr = mix(0.12, 0.66, readiness);
			float linger = 1.0 + 0.6 * storm;
			caps = smoothstep(thr, thr - 0.18, s.jacobian);
			// Lingering foam: up close only, it's too small to see far out
			if (length(p) < 160.0) {
				caps = max(caps, 0.65 * smoothstep(thr, thr - 0.18, rw_crest_state(p, l, 0.8 * linger).x));
				caps = max(caps, 0.35 * smoothstep(thr, thr - 0.18, rw_crest_state(p, l, 1.9 * linger).x));
			}
			caps *= breaking_here * size_ok * readiness;
		}
	}

	// In a blow the big waves break too: white tops on the biggest crests (in patches: not every
	// crest breaks; scattered in rain, many in a gale), foam left behind on their backs as they roll
	// on, and in a storm old foam spread over the sea in marbled lace
	float gale = smoothstep(0.4, 1.8, l.hw_eff) * smoothstep(0.35, 0.9, readiness);
	if (gale > 0.0) {
		vec2 gd = world_xz - rw_group.xy;
		float patchy = 0.6 * rw_world_noise(gd, 19.0) + 0.4 * rw_world_noise(gd, 47.0);
		float half_h = 0.5 * max(l.hw_eff + 0.6 * l.hs_eff, 0.1);
		float big = smoothstep(0.5, 1.05, s.offset.y / half_h);
		if (length(p) < 200.0) {
			float linger = 1.0 + 0.6 * rw_params0.z;
			big = max(big, 0.75 * smoothstep(0.5, 1.05, rw_crest_state(p, l, 1.2 * linger).y / half_h));
			big = max(big, 0.45 * smoothstep(0.5, 1.05, rw_crest_state(p, l, 2.8 * linger).y / half_h));
		}
		float storm_g = rw_params0.z;
		big *= smoothstep(mix(0.5, 0.3, storm_g), mix(0.68, 0.55, storm_g), patchy);
		// Old foam: torn, irregular patches drifting on the sea
		vec2 wq = world_xz - rw_group.xy + 6.0 * vec2(rw_world_noise(world_xz, 113.0), rw_world_noise(world_xz + 37.0, 113.0));
		float blot = smoothstep(0.62, 0.82, 0.7 * rw_world_noise(wq, 150.0) + 0.3 * rw_world_noise(wq, 400.0));
		float old_foam = 0.5 * blot * smoothstep(0.35, 0.7, patchy) * smoothstep(0.4, 1.0, rw_params0.z);
		caps = max(caps, max(big, old_foam) * gale);
	}

	// Breaking rollers: white crest, the face in front of it and the turbulent trail behind, then
	// churned white water left over the whole surf zone
	float breaking = 0.0;
	float pieces = 0.6 * rw_world_noise(world_xz, 60.0) + 0.4 * rw_world_noise(world_xz, 150.0);
	vec2 sq = world_xz + 5.0 * vec2(rw_world_noise(world_xz, 131.0), rw_world_noise(world_xz + 71.0, 131.0));
	float churn = rw_world_noise(sq - rw_group.xy * 0.25, 210.0);
	if (l.roll_amp > 1e-3) {
		// 0 at the crest, growing seaward; just under 2 pi is the face in front of it
		float behind = mod(s.roller_phase, rw_tau);
		float face = smoothstep(rw_tau - 0.9, rw_tau - 0.1, behind);
		float trail = 1.0 - smoothstep(0.2, 3.4, behind);
		// Whitewater comes in pieces scattered across the surf zone, not one long band
		float strength = l.breaking * smoothstep(0.02, 0.2, l.roll_amp);
		breaking = strength * max(max(s.roller_crest, face), 0.85 * trail) * smoothstep(0.15, 0.4, pieces);
		breaking = max(breaking, strength * smoothstep(0.1, 0.4, l.roll_amp) * (0.25 + 0.45 * smoothstep(0.4, 0.75, churn)));
	}

	// Swash: each wave runs up the beach in a sheet of foam and slides back
	float run = 1.6 + 2.0 * min(l.incoming, 1.5);
	float wash = smoothstep(run, 0.3, l.shore + 0.6 * cos(s.roller_phase)) * (0.15 + 0.85 * smoothstep(0.3, 1.2, l.incoming))
		* smoothstep(0.05, 0.2, l.incoming)
		* mix(0.55, 1.0, smoothstep(0.15, 0.7, l.surf));

	// Waves slamming into a wall, cliff or quay: a burst of white water with every impact that
	// spreads out from the wall and lingers
	float slam = 0.0;
	// (steep beaches with deep water at the shore get some white water too)
	float wall = smoothstep(1.5, 5.0, l.depth) * mix(0.5, 1.0, l.bank);
	float reach = 1.5 + 3.5 * min(l.incoming, 2.0);
	if (wall > 0.0 && l.shore < reach && l.incoming > 0.05) {
		float half_h = 0.5 * max(l.hw_eff + l.hs_eff + l.hc_eff, 0.05);
		float impact = smoothstep(-0.3, 0.6, s.offset.y / half_h);
		if (length(p) < 200.0) {
			impact = max(impact, 0.8 * smoothstep(-0.3, 0.6, rw_crest_state(p, l, 1.5).y / half_h));
			impact = max(impact, 0.55 * smoothstep(-0.3, 0.6, rw_crest_state(p, l, 3.5).y / half_h));
		}
		slam = wall * smoothstep(reach, 0.3, l.shore) * smoothstep(0.05, 0.3, l.incoming)
			* max(impact, 0.5 * smoothstep(0.25, 0.65, churn)) * (0.7 + 0.3 * smoothstep(0.2, 0.5, pieces));
	}

	// Churned water behind boats
	float wake = rw_in_wake_window(p) ? rw_wake_at(p + rw_cam.xy).r : 0.0;

	float foam = clamp(max(max(caps, breaking) * l.taper, max(max(wash, slam), wake)), 0.0, 1.0);
	if (foam <= 0.0) return 0.0;
	// Break up into bubbly patches; dense foam stays solid
	float tex = rw_foam_texture(world_xz);
	foam *= smoothstep(0.15, 0.65, tex + foam * 0.55 - 0.25);
	return clamp(foam, 0.0, 1.0);
}

#endif // INCLUDE_REALWAVES

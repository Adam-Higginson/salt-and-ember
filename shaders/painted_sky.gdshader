// A painted dusk sky (home waters, the opening). Three layers:
//   1. a gradient from deep violet overhead, through mauve and rose, to a warm
//      orange band at the horizon, with a soft sun and a wide glow low down;
//   2. high streaks of stratus and drifting cumulus, both made from fractal
//      noise (FBM) that is pushed sideways by more noise (domain warping) so
//      the edges look brushed, not like smoke;
//   3. a painted finish: the cloud light is cut into a few soft bands (shadow,
//      mid, lit, rim), the edges are ragged like brush strokes, and a faint
//      canvas weave sits on top.
// The clouds are lit from the sun's direction: a cheap fake, comparing the
// cloud's thickness here with its thickness a little towards the sun. Thinner
// that way means we're on the edge the sun reaches, so it glows orange/pink.
// Everything is found from the view direction, never the screen, so nothing
// swims when the camera turns. A sky shader also feeds Godot's ambient light
// and reflections (the sea mirrors it), which is why the weave and the
// small detail switch off when AT_CUBEMAP_PASS says it's only being baked.
shader_type sky;

group_uniforms sun;
// Use the scene's first DirectionalLight3D as the sun (its direction, so the
// glow and the cloud light always match the light on the boat). Off: use
// [sun_direction] below.
uniform bool use_scene_sun = true;
// Where the sun is, as a direction from the viewer towards it (not
// necessarily normalised). Only used when [use_scene_sun] is off or the
// scene has no directional light.
uniform vec3 sun_direction = vec3(-0.37, 0.06, -0.93);
// Sun disc size as an angle in degrees, and how soft its edge is.
uniform float sun_size : hint_range(0.1, 10.0) = 2.2;
uniform float sun_softness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 sun_color : source_color = vec4(1.0, 0.66, 0.34, 1.0);
// Brightness of the sun disc and of the wide warm glow round it. Above 1
// makes the disc bloom (Environment glow).
uniform float sun_strength : hint_range(0.0, 8.0) = 3.0;
uniform float glow_strength : hint_range(0.0, 3.0) = 0.5;
// How wide the glow is: smaller spreads it further across the sky.
uniform float glow_tightness : hint_range(1.0, 24.0) = 3.5;

group_uniforms sky_colors;
// From the top down: overhead, high sky, the rosy mid sky, the horizon band.
uniform vec4 zenith_color : source_color = vec4(0.1, 0.07, 0.27, 1.0);
uniform vec4 high_color : source_color = vec4(0.3, 0.15, 0.5, 1.0);
uniform vec4 mid_color : source_color = vec4(0.66, 0.34, 0.55, 1.0);
uniform vec4 horizon_color : source_color = vec4(1.0, 0.42, 0.16, 1.0);
// The sea haze below the horizon line, which the sky fades into.
uniform vec4 below_color : source_color = vec4(0.36, 0.25, 0.5, 1.0);
// How high (0 horizon, 1 straight up) the mid and high colours sit.
uniform float mid_height : hint_range(0.02, 0.8) = 0.16;
uniform float high_height : hint_range(0.1, 1.0) = 0.5;

group_uniforms clouds;
// A seamless noise picture the clouds are cut from (a NoiseTexture2D,
// seamless, about 512 px).
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
// How much of the sky is cloud, 0 clear to 1 overcast.
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.64;
// Cloud size: bigger numbers make smaller, more numerous clouds.
uniform float cloud_scale : hint_range(0.05, 3.0) = 0.2;
// How fast the clouds drift, in noise units per second. 0 freezes them.
uniform float drift_speed : hint_range(0.0, 0.05) = 0.004;
// How far the warp bends the shapes (0 is smooth blobs; ~1 is brushed).
uniform float warp_amount : hint_range(0.0, 2.0) = 0.45;
// The share of the sky given to long high streaks of stratus.
uniform float streak_cover : hint_range(0.0, 1.0) = 0.5;
// How stretched the streaks are (1 is round).
uniform float streak_length : hint_range(1.0, 12.0) = 6.0;
// The clouds fade out between these heights above the horizon, so they
// melt into the haze on the horizon instead of ending on a line.
uniform float horizon_fade_start : hint_range(-0.2, 0.5) = 0.0;
uniform float horizon_fade_end : hint_range(0.0, 0.6) = 0.2;

group_uniforms cloud_light;
// How many steps of light the clouds are cut into. 2 is flat and graphic,
// 3 or 4 reads as painted.
uniform float band_count : hint_range(2.0, 6.0) = 4.0;
// How soft the step between bands is. 0 is hard like cut paper; 0.3 blends.
uniform float band_softness : hint_range(0.0, 0.5) = 0.16;
// How much the sun-facing edge lifts the light, and how much a cloud's thick
// middle is shaded.
uniform float edge_light : hint_range(0.0, 12.0) = 7.0;
uniform float body_shadow : hint_range(0.0, 1.0) = 0.6;
// How far towards the sun to look for the lit edge (bigger gives fatter
// rims).
uniform float light_reach : hint_range(0.01, 0.4) = 0.12;
// Clouds in the sun's direction, and clouds low in the sky, catch more light.
uniform float backlight : hint_range(0.0, 1.5) = 0.45;
// The four light steps, darkest to brightest.
uniform vec4 shadow_color : source_color = vec4(0.22, 0.14, 0.38, 1.0);
uniform vec4 shade_color : source_color = vec4(0.52, 0.29, 0.5, 1.0);
uniform vec4 lit_color : source_color = vec4(1.0, 0.5, 0.3, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.62, 0.34, 1.0);
// How much of the sky behind shows through the shadowed side (0 solid paint).
uniform float shadow_see_through : hint_range(0.0, 1.0) = 0.12;

group_uniforms painted_finish;
// How ragged the cloud edges are, like dry brush strokes.
uniform float brush_edge : hint_range(0.0, 0.3) = 0.05;
// How much the paint's brush streaks vary the light across a cloud.
uniform float brush_strength : hint_range(0.0, 0.5) = 0.12;
// Canvas weave on top of everything. Off while only baking the ambient light.
uniform float canvas_strength : hint_range(0.0, 0.2) = 0.03;
uniform float canvas_density : hint_range(100.0, 2000.0) = 800.0;

const mat2 TURN = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));

// Fractal noise: [octaves] copies of the noise, each twice as fine and half as
// strong as the one before, turned a little each time so they don't line up.
// Returns about 0 to 1, centred on 0.5.
float fbm(vec2 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float total = 0.0;
	for (int i = 0; i < octaves; i++) {
		sum += texture(cloud_noise, p).r * amp;
		total += amp;
		p = TURN * p * 2.03 + vec2(0.31, 0.17);
		amp *= 0.42;
	}
	return sum / total;
}

// A cloud thickness at [p]: fractal noise with the position first pushed
// about by two slower noises (the domain warp), which drags the blobs into
// swirled, brushed shapes.
float cloud_field(vec2 p, int octaves, float warp) {
	vec2 q = vec2(texture(cloud_noise, p * 0.45 + vec2(0.13, 0.71)).r,
			texture(cloud_noise, p * 0.45 + vec2(0.57, 0.29)).r) - 0.5;
	return fbm(p + q * warp * 2.0, octaves);
}

// A few soft steps instead of a smooth ramp: [level] 0..1 in, 0..1 out.
float posterise(float level, float bands, float softness) {
	float x = clamp(level, 0.0, 0.9999) * bands;
	float step_at = floor(x);
	float soft = smoothstep(0.5 - softness, 0.5 + softness, fract(x));
	return (step_at + soft) / bands;
}

// The four light colours as one ramp: [t] 0 shadow, 1 rim.
vec3 cloud_paint(float t) {
	vec3 c = mix(shadow_color.rgb, shade_color.rgb, smoothstep(0.0, 0.34, t));
	c = mix(c, lit_color.rgb, smoothstep(0.34, 0.68, t));
	return mix(c, rim_color.rgb, smoothstep(0.68, 1.0, t));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun = normalize(sun_direction);
	if (use_scene_sun && LIGHT0_ENABLED) {
		sun = normalize(LIGHT0_DIRECTION);
	}
	float up = dir.y;
	float toward = max(dot(dir, sun), 0.0);

	// --- Gradient -----------------------------------------------------------
	float h = clamp(up, 0.0, 1.0);
	vec3 col = mix(horizon_color.rgb, mid_color.rgb, smoothstep(0.0, mid_height, h));
	col = mix(col, high_color.rgb, smoothstep(mid_height * 0.6, high_height, h));
	col = mix(col, zenith_color.rgb, smoothstep(high_height * 0.6, 1.0, h));
	// The sky cools away from the sun's side.
	col = mix(col, col * vec3(0.8, 0.75, 1.05), (1.0 - toward) * 0.25);
	// Wide warm glow round the sun, then a tighter one.
	float glow = pow(toward, glow_tightness) * 0.6 + pow(toward, glow_tightness * 9.0) * 0.8;
	col += sun_color.rgb * glow * glow_strength;

	// --- Clouds -------------------------------------------------------------
	// The cloud layer is a flat ceiling: a direction becomes a position on a
	// plane, so clouds shrink and crowd towards the horizon.
	float fade = smoothstep(horizon_fade_start, horizon_fade_end, up);
	if (fade > 0.0) {
		vec2 plane = dir.xz / (max(up, 0.0) + 0.3);
		vec2 sun_plane = normalize(sun.xz + vec2(0.0001));
		vec2 wind = vec2(TIME * drift_speed, TIME * drift_speed * 0.35);
		int octaves = AT_CUBEMAP_PASS ? 3 : 5;
		int light_octaves = AT_CUBEMAP_PASS ? 2 : 3;

		// Cumulus: round, banded and lit from the side.
		vec2 p = plane * cloud_scale + wind;
		float f = cloud_field(p, octaves, warp_amount);
		// The same cloud a step towards the sun: if it is thinner there, this
		// is the edge the sun reaches.
		float f_sun = cloud_field(p + sun_plane * light_reach, light_octaves, warp_amount);
		float brush = texture(cloud_noise, p * vec2(7.0, 1.3) + 0.4).r - 0.5;
		float thr = mix(0.72, 0.4, cloud_cover);
		float ragged = (AT_CUBEMAP_PASS ? 0.0 : brush_edge) * brush;
		float body = smoothstep(thr - 0.06, thr + 0.05, f + ragged);
		float thick = smoothstep(thr, thr + 0.22, f);
		float rim = clamp((f - f_sun) * edge_light, 0.0, 1.0);
		float low = 1.0 - clamp(up * 2.2, 0.0, 1.0);
		float sunward = pow(toward, 1.5) * 0.5 + low * 0.35;
		float level = 0.16 + rim * 0.55 + sunward * backlight - thick * body_shadow
				+ brush * brush_strength * 2.0;
		level = posterise(level, band_count, band_softness);
		vec3 paint = cloud_paint(level);
		col = mix(col, mix(col, paint, 1.0 - shadow_see_through * (1.0 - level)), body * fade);

		// Stratus: long thin streaks, stretched along one axis, higher up and
		// always catching the colour of the low sun.
		vec2 sp = vec2(plane.x / streak_length, plane.y) * cloud_scale * 1.3
				+ wind * 0.6 + vec2(0.37, 0.52);
		float s = cloud_field(sp, AT_CUBEMAP_PASS ? 2 : 4, warp_amount * 0.5);
		float s_sun = cloud_field(sp + vec2(sun_plane.x / streak_length, sun_plane.y) * 0.08,
				light_octaves, warp_amount * 0.5);
		float sthr = mix(0.74, 0.46, streak_cover);
		float sbody = smoothstep(sthr - 0.05, sthr + 0.08, s) * 0.85;
		float slevel = posterise(0.35 + clamp((s - s_sun) * edge_light * 0.8, 0.0, 1.0) * 0.4
				+ pow(toward, 1.5) * 0.35 + low * 0.3, band_count, band_softness);
		float sfade = smoothstep(horizon_fade_start, horizon_fade_end * 1.5, up);
		col = mix(col, cloud_paint(slevel), sbody * sfade * (1.0 - body * fade * 0.6));
	}

	// --- Sun disc -----------------------------------------------------------
	float disc_edge = cos(radians(sun_size));
	float soft = mix(0.0001, 0.004, sun_softness) * sun_size;
	float disc = smoothstep(disc_edge - soft, disc_edge + soft, dot(dir, sun));
	col = mix(col, sun_color.rgb * sun_strength, disc);

	// --- Below the horizon: sea haze ----------------------------------------
	col = mix(col, below_color.rgb, smoothstep(0.02, -0.06, up));

	// --- Canvas ---------------------------------------------------------------
	if (!AT_CUBEMAP_PASS) {
		float weave = sin(dir.x * canvas_density + dir.y * canvas_density * 0.5)
				* sin(dir.z * canvas_density - dir.y * canvas_density * 0.7);
		col *= 1.0 + weave * canvas_strength;
	}
	COLOR = col;
}

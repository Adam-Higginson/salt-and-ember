// A painted dusk sky (home waters, the opening). Four layers:
//   1. a gradient from deep violet overhead, through purple and rose, to a
//      glowing orange band at the horizon (hotter on the sun's side), with a
//      sun disc and a wide warm glow round it;
//   2. high streaks of stratus: flat 2D fractal noise (FBM) on a ceiling,
//      pushed about by more noise (domain warping) so they look brushed;
//   3. big cumulus, raymarched in 3D: a slab of sky between two heights is
//      filled with 3D noise, and each view ray takes a few steps through it,
//      adding up how thick the cloud is. At each step a few more steps go
//      towards the sun to see how much cloud is in the way (Beer's law), so the
//      side facing the sun is lit coral and orange and the far side, and the
//      underside, stay violet. The light is then cut into a few soft painted
//      bands and the edges are roughened like brush strokes;
//   4. a faint canvas weave.
// The cumulus are costly, so they are drawn in a half-resolution pass
// (AT_HALF_RES_PASS) and laid over the full-resolution sky, and the cube map
// Godot bakes for ambient light and reflections (AT_CUBEMAP_PASS) uses fewer
// steps. Everything is found from the view direction, never the screen, so
// nothing swims when the camera turns.
shader_type sky;
render_mode use_half_res_pass;

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
uniform float sun_size : hint_range(0.1, 10.0) = 2.6;
uniform float sun_softness : hint_range(0.0, 1.0) = 0.4;
uniform vec4 sun_color : source_color = vec4(1.0, 0.84, 0.55, 1.0);
// Brightness of the sun disc. Above about 2 the disc blooms (Environment glow).
uniform float sun_strength : hint_range(0.0, 12.0) = 5.0;
// The wide warm glow round the sun: its colour, strength and how wide it is
// (smaller spreads it further across the sky).
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float glow_strength : hint_range(0.0, 3.0) = 0.9;
uniform float glow_tightness : hint_range(1.0, 24.0) = 5.0;

group_uniforms sky_colors;
// From the top down: overhead, high sky, the purple mid sky, and the horizon
// band, which is orange on the sun's side and rose away from it.
uniform vec4 zenith_color : source_color = vec4(0.17, 0.13, 0.33, 1.0);
uniform vec4 high_color : source_color = vec4(0.3, 0.22, 0.48, 1.0);
uniform vec4 mid_color : source_color = vec4(0.5, 0.3, 0.52, 1.0);
uniform vec4 horizon_color : source_color = vec4(1.0, 0.56, 0.26, 1.0);
uniform vec4 horizon_away_color : source_color = vec4(0.66, 0.4, 0.5, 1.0);
// The sea haze below the horizon line, which the sky fades into.
uniform vec4 below_color : source_color = vec4(0.3, 0.24, 0.4, 1.0);
// How high (0 horizon, 1 straight up) the mid and high colours sit.
uniform float mid_height : hint_range(0.02, 0.8) = 0.12;
uniform float high_height : hint_range(0.1, 1.0) = 0.45;

group_uniforms cumulus;
// The big clouds are a 3D slab of sky between these heights, in metres.
uniform float cloud_bottom = 1400.0;
uniform float cloud_top = 3400.0;
// How much of the sky is cloud, 0 clear to 1 overcast.
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;
// How patchy the cover is: big clear gaps and big banks, from the 2D noise.
uniform float cover_patchiness : hint_range(0.0, 2.0) = 0.9;
// How thick the cloud is (light lost per metre). More is more solid paint.
uniform float cloud_density : hint_range(0.0, 0.05) = 0.012;
// Cloud size, in metres per noise repeat, and the size of the eroded puffs.
uniform float cloud_size = 9000.0;
uniform float puff_size = 1800.0;
// How much the small puffs eat into the edges (0 is smooth blobs).
uniform float puff_erode : hint_range(0.0, 1.0) = 0.45;
// Wind, in metres per second (x, z). Slow: these are big, far clouds.
uniform vec2 wind = vec2(9.0, 3.0);
// Clouds fade out by this distance (metres), so they melt into the horizon.
uniform float cloud_far = 42000.0;
// 3D noise (NoiseTexture3D, seamless): smooth fractal noise for the shapes and
// cellular (Worley) noise, inverted, for the puffs.
uniform sampler3D cloud_shape : filter_linear, repeat_enable;
uniform sampler3D cloud_puffs : filter_linear, repeat_enable;

group_uniforms cumulus_light;
// Steps along each view ray through the slab, and towards the sun from each.
// The ambient cube map uses half (at least 4) and one sun step.
uniform int march_steps : hint_range(0, 48) = 18;
uniform int light_steps : hint_range(0, 6) = 3;
// How far each step towards the sun goes, in metres.
uniform float light_step = 260.0;
// Beer's law: how quickly cloud between here and the sun dims the light.
uniform float light_absorption : hint_range(0.0, 4.0) = 1.1;
// The powder effect: thin wisps and edges facing away from the sun are
// darker than Beer's law alone says (light scatters in from the inside).
uniform float powder : hint_range(0.0, 1.0) = 0.5;
// Silver lining: clouds between you and the sun glow at their edges.
// [silver_focus] is how forward the scattering is (0 even, 0.9 a tight halo).
uniform float silver_lining : hint_range(0.0, 2.0) = 0.8;
uniform float silver_focus : hint_range(0.0, 0.95) = 0.7;
// Light the clouds get from the violet sky round them, bottom and top.
uniform float ambient_bottom : hint_range(0.0, 1.0) = 0.08;
uniform float ambient_top : hint_range(0.0, 1.0) = 0.3;
// Overall brightness of the cloud light before it is cut into bands.
uniform float light_gain : hint_range(0.2, 3.0) = 1.0;

group_uniforms cloud_paint;
// How many steps of light the clouds are cut into. 2 is flat and graphic,
// 3 or 4 reads as painted.
uniform float band_count : hint_range(2.0, 8.0) = 4.0;
// How soft the step between bands is. 0 is hard like cut paper; 0.3 blends.
uniform float band_softness : hint_range(0.0, 0.5) = 0.2;
// The four light steps, darkest to brightest: violet underside, mauve
// shade, coral lit side, orange-gold rim.
uniform vec4 shadow_color : source_color = vec4(0.26, 0.19, 0.42, 1.0);
uniform vec4 shade_color : source_color = vec4(0.5, 0.3, 0.52, 1.0);
uniform vec4 lit_color : source_color = vec4(0.95, 0.47, 0.32, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.7, 0.4, 1.0);
// Brightness of the lit colours (above 1 lets the rims bloom a little).
uniform float lit_strength : hint_range(0.5, 3.0) = 1.3;
// Far clouds take on the horizon's colour by this share.
uniform float cloud_haze : hint_range(0.0, 1.0) = 0.55;
// How crisp the cloud's outline is: 0 soft, 1 cut like a painted shape.
uniform float edge_crisp : hint_range(0.0, 1.0) = 0.6;

group_uniforms streaks;
// A seamless 2D noise picture (a NoiseTexture2D, about 512 px). Used for the
// stratus streaks, the patchy cover and the brushed edges.
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
// The share of the sky given to long high streaks of stratus.
uniform float streak_cover : hint_range(0.0, 1.0) = 0.45;
// How stretched the streaks are (1 is round), their size, and how much the
// warp bends them.
uniform float streak_length : hint_range(1.0, 12.0) = 6.0;
uniform float streak_scale : hint_range(0.05, 3.0) = 0.26;
uniform float warp_amount : hint_range(0.0, 2.0) = 0.45;
// How fast the streaks drift, in noise units per second.
uniform float drift_speed : hint_range(0.0, 0.05) = 0.003;

group_uniforms painted_finish;
// How ragged the cloud edges are, like dry brush strokes.
uniform float brush_edge : hint_range(0.0, 0.5) = 0.18;
// Canvas weave on top of everything. Off while only baking the ambient light.
uniform float canvas_strength : hint_range(0.0, 0.2) = 0.025;
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


// Streak thickness at [p]: fractal noise with the position first pushed
// about by a slower noise (the domain warp), which drags it into brushed shapes.
float streak_field(vec2 p, int octaves, float warp) {
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
	vec3 c = mix(shadow_color.rgb, shade_color.rgb, smoothstep(0.0, 0.3, t));
	c = mix(c, lit_color.rgb * lit_strength, smoothstep(0.3, 0.62, t));
	return mix(c, rim_color.rgb * lit_strength, smoothstep(0.62, 1.0, t));
}


// The horizon colour in a direction: orange towards the sun, rose away.
vec3 horizon_at(float toward) {
	return mix(horizon_away_color.rgb, horizon_color.rgb, smoothstep(0.0, 0.9, toward));
}


float remap01(float v, float lo, float hi) {
	return clamp((v - lo) / max(hi - lo, 0.0001), 0.0, 1.0);
}


// How thick the cumulus is (light lost per metre) at [p], metres from the
// viewer. [puffs] adds the eroding small puffs (skipped for the sun steps).
float cumulus_at(vec3 p, bool puffs) {
	float height = (p.y - cloud_bottom) / (cloud_top - cloud_bottom);
	if (height <= 0.0 || height >= 1.0) {
		return 0.0;
	}
	vec3 q = p + vec3(wind.x, 0.0, wind.y) * TIME;
	// Patchy cover: some parts of the sky are banks, some are clear.
	float patchy = texture(cloud_noise, q.xz / (cloud_size * 3.0)).r - 0.5;
	float cover = clamp(cloud_cover + patchy * cover_patchiness, 0.0, 1.0);
	// Cumulus shape: a flat base that fills in quickly, a rounded top.
	float profile = smoothstep(0.0, 0.1, height) * smoothstep(1.0, 0.3, height);
	float base = texture(cloud_shape, q / cloud_size * vec3(1.0, 2.2, 1.0)).r;
	float shape = remap01(base * profile, 1.0 - cover, 1.0);
	if (puffs && shape > 0.0) {
		float puff = texture(cloud_puffs, q / puff_size).r;
		shape = remap01(shape, (1.0 - puff) * puff_erode, 1.0);
	}
	return shape * cloud_density;
}


// Henyey-Greenstein phase, scaled so even scattering is 1: how much sunlight
// bounces towards the viewer for an angle whose cosine is [c].
float phase_hg(float c, float g) {
	float g2 = g * g;
	return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * c, 1.5);
}


// Raymarches the cumulus slab along [dir]. Returns premultiplied colour and
// coverage (alpha).
vec4 cumulus(vec3 dir, vec3 sun, bool baking) {
	if (dir.y < 0.015 || march_steps <= 0) {
		return vec4(0.0);
	}
	float t_in = cloud_bottom / dir.y;
	if (t_in > cloud_far) {
		return vec4(0.0);
	}
	// Low rays cross the slab on a long slant; cap the stretch so the steps
	// stay short enough to see the shapes.
	float t_out = min(cloud_top / dir.y, t_in + (cloud_top - cloud_bottom) * 4.0);
	int steps = baking ? max(march_steps / 2, 4) : march_steps;
	int sun_steps = baking ? min(light_steps, 1) : light_steps;
	float dt = (t_out - t_in) / float(steps);
	// Start each ray a fixed random part of a step in, so the steps don't
	// show as rings. Tied to the direction, so it never crawls.
	float jitter = fract(sin(dot(floor(dir * 900.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float t = t_in + dt * jitter;
	float c = dot(dir, sun);
	float phase = mix(1.0, phase_hg(c, silver_focus), silver_lining * 0.35);

	float through = 1.0;
	float light_sum = 0.0;
	float dist_sum = 0.0;
	for (int i = 0; i < steps; i++) {
		vec3 p = dir * t;
		float d = cumulus_at(p, true);
		if (d > 0.0) {
			// How much cloud lies between here and the sun.
			float depth_to_sun = 0.0;
			vec3 lp = p;
			for (int j = 0; j < sun_steps; j++) {
				lp += sun * light_step;
				depth_to_sun += cumulus_at(lp, false) * light_step;
			}
			float beer = exp(-depth_to_sun * light_absorption);
			float powder_term = mix(1.0, 1.0 - exp(-d * dt * 2.0), powder);
			float height = (p.y - cloud_bottom) / (cloud_top - cloud_bottom);
			float light = beer * powder_term * phase
					+ mix(ambient_bottom, ambient_top, height);
			float a = 1.0 - exp(-d * dt);
			light_sum += through * a * light;
			dist_sum += through * a * t;
			through *= 1.0 - a;
			if (through < 0.03) {
				break;
			}
		}
		t += dt;
	}
	float alpha = 1.0 - through;
	if (alpha < 0.001) {
		return vec4(0.0);
	}
	float light = light_sum / alpha;
	float dist = dist_sum / alpha;
	// Painted: the light is cut into a few soft bands, then coloured.
	vec3 col = cloud_paint(posterise(light * light_gain, band_count, band_softness));
	// Far clouds sink into the horizon's colour, and fade out at the far edge.
	float far = smoothstep(cloud_far * 0.25, cloud_far, dist);
	col = mix(col, horizon_at(max(c, 0.0)) * 0.9, far * cloud_haze);
	alpha *= 1.0 - smoothstep(cloud_far * 0.6, cloud_far, dist);
	return vec4(col * alpha, alpha);
}


void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun = normalize(sun_direction);
	if (use_scene_sun && LIGHT0_ENABLED) {
		sun = normalize(LIGHT0_DIRECTION);
	}

	if (AT_HALF_RES_PASS) {
		// Only the cumulus, at half resolution; the full pass lays them over.
		vec4 clouds = cumulus(dir, sun, AT_CUBEMAP_PASS);
		COLOR = clouds.rgb;
		ALPHA = clouds.a;
	} else {
		float up = dir.y;
		float toward = max(dot(dir, sun), 0.0);

		// --- Gradient -------------------------------------------------------
		float h = clamp(up, 0.0, 1.0);
		vec3 col = mix(horizon_at(toward), mid_color.rgb, smoothstep(0.0, mid_height, h));
		col = mix(col, high_color.rgb, smoothstep(mid_height * 0.6, high_height, h));
		col = mix(col, zenith_color.rgb, smoothstep(high_height * 0.6, 1.0, h));
		// Wide warm glow round the sun, hugging the horizon, then a tighter one.
		float low = 1.0 - smoothstep(0.0, 0.35, abs(up));
		float glow = pow(toward, glow_tightness) * (0.35 + 0.65 * low)
				+ pow(toward, glow_tightness * 12.0) * 1.2;
		col += glow_color.rgb * glow * glow_strength;

		// --- Stratus streaks ------------------------------------------------
		vec2 plane = dir.xz / (max(up, 0.0) + 0.3);
		float brush = texture(cloud_noise, plane * vec2(1.8, 0.35) + 0.4).r - 0.5;
		float fade = smoothstep(0.0, 0.25, up);
		if (fade > 0.0 && streak_cover > 0.0) {
			vec2 sun_plane = normalize(sun.xz + vec2(0.0001));
			vec2 wind_2d = vec2(TIME * drift_speed, TIME * drift_speed * 0.35);
			vec2 sp = vec2(plane.x / streak_length, plane.y) * streak_scale + wind_2d;
			int octaves = AT_CUBEMAP_PASS ? 2 : 4;
			float s = streak_field(sp, octaves, warp_amount * 0.5);
			float s_sun = streak_field(sp + vec2(sun_plane.x / streak_length, sun_plane.y) * 0.08,
					2, warp_amount * 0.5);
			float sthr = mix(0.74, 0.46, streak_cover);
			float sbody = smoothstep(sthr - 0.04, sthr + 0.06, s + brush * brush_edge * 0.4) * 0.8;
			float slevel = 0.3 + clamp((s - s_sun) * 6.0, 0.0, 1.0) * 0.3
					+ pow(toward, 2.0) * 0.45 + (1.0 - h * 2.0) * 0.15;
			slevel = posterise(slevel, band_count, band_softness);
			col = mix(col, cloud_paint(slevel), sbody * fade);
		}

		// --- Sun disc -------------------------------------------------------
		float disc_edge = cos(radians(sun_size));
		float soft = mix(0.0001, 0.004, sun_softness) * sun_size;
		float disc = smoothstep(disc_edge - soft, disc_edge + soft, dot(dir, sun));
		col = mix(col, sun_color.rgb * sun_strength, disc);

		// --- Cumulus (from the half-resolution pass) ------------------------
		vec4 half_res = HALF_RES_COLOR;
		if (half_res.a > 0.001) {
			vec3 cloud_col = half_res.rgb / half_res.a;
			// Painted outline: the soft coverage is cut sharper, and roughened
			// with the brush noise so edges look dragged, not smoky.
			float ragged = AT_CUBEMAP_PASS ? 0.0 : brush * brush_edge;
			float cut = smoothstep(0.5 - 0.5 * (1.0 - edge_crisp), 0.5 + 0.5 * (1.0 - edge_crisp),
					half_res.a + ragged);
			float cover = mix(half_res.a, cut, edge_crisp) * smoothstep(0.0, 0.05, up);
			col = mix(col, cloud_col, clamp(cover, 0.0, 1.0));
		}

		// --- Below the horizon: sea haze ------------------------------------
		col = mix(col, below_color.rgb, smoothstep(0.01, -0.06, up));

		// --- Canvas ---------------------------------------------------------
		if (!AT_CUBEMAP_PASS) {
			float weave = sin(dir.x * canvas_density + dir.y * canvas_density * 0.5)
					* sin(dir.z * canvas_density - dir.y * canvas_density * 0.7);
			col *= 1.0 + weave * canvas_strength;
		}
		COLOR = col;
	}
}

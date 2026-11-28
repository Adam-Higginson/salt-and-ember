// The sea. Gerstner waves (the same maths as scripts/sea/waves.gd) move the
// surface; detail ripples, rain rings and foam (on crests, along the hull and
// in the wake) are added per pixel. Sea (scripts/sea/sea.gd) sets the
// uniforms every frame. Godot's fog is applied on top, which hides the edge.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// --- Waves (set by Sea from a WaveSettings resource) ----------------------
uniform int wave_count = 0;
// Per layer: direction x, direction z, wave number, speed.
uniform vec4 wave_a[4];
// Per layer: amplitude, sideways push, unused, unused.
uniform vec4 wave_b[4];
// Seconds, already multiplied by the settings' time scale.
uniform float wave_time = 0.0;

// --- The ship (for the hull cut-out, the hull foam and the wake) ----------
uniform mat4 hull_inverse = mat4(1.0);
// Half the hull's width (x) and length (y), in metres: the box from the
// stern to where the bow starts.
uniform vec2 hull_half = vec2(6.0, 15.0);
// How far the pointed bow reaches forward of the box, at the waterline.
uniform float bow_reach = 0.0;
// How strong the wake is: 0 moored, 1 at full sail.
uniform float wake = 0.0;
// How far astern the wake's foam lasts before it's all broken up, in metres.
uniform float wake_length = 42.0;

// --- Weather ---------------------------------------------------------------
// Rain intensity, 0 to 1: how many rain rings dimple the surface.
uniform float rain = 0.0;

// --- Look ------------------------------------------------------------------
uniform vec4 deep_color : source_color = vec4(0.025, 0.06, 0.075, 1.0);
uniform vec4 crest_color : source_color = vec4(0.07, 0.22, 0.23, 1.0);
uniform vec4 foam_color : source_color = vec4(0.62, 0.68, 0.7, 1.0);
uniform float roughness_water : hint_range(0.0, 1.0) = 0.04;
// Seamless normal maps scrolled against each other for the fine chop.
uniform sampler2D detail_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 0.06;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.5;
// A seamless noise for breaking up foam.
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
// How pointed a crest must be before it foams.
uniform float crest_foam_from : hint_range(0.0, 1.0) = 0.55;
uniform float hull_foam_width = 1.4;
// How much wider the foam at the bow grows while the ship is under way.
uniform float bow_wave = 1.6;
// Pale glowing plankton stirred up in the foam along the hull and the wake.
uniform vec4 glimmer_color : source_color = vec4(0.25, 0.85, 0.8, 1.0);
uniform float glimmer : hint_range(0.0, 4.0) = 1.2;
// How much crests and foam glow by themselves at night.
uniform float night_glow : hint_range(0.0, 2.0) = 0.6;
// The misty sky the surface mirrors at glancing angles.
uniform vec4 sky_reflection : source_color = vec4(0.2, 0.24, 0.28, 1.0);

// The Grave of the Lanterns far below (#182): a few faint warm lights deep
// under the surface. grave is how much shows, 0 (the open sea) to 1; set by
// the Sea from a cutscene's @grave cue.
uniform float grave = 0.0;
uniform vec4 grave_color : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float grave_energy = 0.45;
// What share of the places one could be actually has a light.
uniform float grave_share : hint_range(0.0, 1.0) = 0.06;

// --- Dusk (home waters) ---------------------------------------------------
// Everything below defaults to "off", so the night sea (the Grave, the ship's
// sea) looks exactly as before. Home waters' own material turns it on.
// How much the surface mirrors the dusk sky below instead of the flat
// [sky_reflection] colour: 0 is the night sea, 1 the dusk sky.
uniform float reflect_sky : hint_range(0.0, 1.0) = 0.0;
// The dusk sky as the water sees it: the horizon, the rosy middle, overhead.
// Match these to the sky shader's colours.
uniform vec4 sky_horizon : source_color = vec4(1.0, 0.42, 0.16, 1.0);
uniform vec4 sky_mid : source_color = vec4(0.66, 0.34, 0.55, 1.0);
uniform vec4 sky_zenith : source_color = vec4(0.1, 0.07, 0.27, 1.0);
// The direction towards the sun (world space) and its colour. Match the Sun
// node's direction (the sky shader reads the light itself; a surface
// shader can't, so it's set here).
uniform vec3 sky_sun_direction = vec3(-0.37, 0.055, -0.93);
uniform vec4 sky_sun_color : source_color = vec4(1.0, 0.66, 0.34, 1.0);
// How sharply the water turns reflective at a glancing angle (the Fresnel
// power: smaller reflects more, from nearer).
uniform float fresnel_power : hint_range(1.0, 8.0) = 4.0;
// Broken painted streaks of sunlight on the swell, towards the sun: how
// strong (0 is none), how wide the streak is, and its colour. Pinned to the
// world, so it doesn't swim as the camera moves.
uniform float glitter : hint_range(0.0, 8.0) = 0.0;
uniform float glitter_width : hint_range(0.0, 1.0) = 0.5;
uniform vec4 glitter_color : source_color = vec4(1.0, 0.78, 0.5, 1.0);
// Far water melts into [far_color] between [far_start] and [far_end] metres
// from the camera, as much as [far_blend] (0 is none).
uniform float far_blend : hint_range(0.0, 1.0) = 0.0;
uniform vec4 far_color : source_color = vec4(0.5, 0.34, 0.52, 1.0);
uniform float far_start = 40.0;
uniform float far_end = 260.0;
// 0 is soft foam; towards 1 it's cut into crisp painted shapes.
uniform float foam_crisp : hint_range(0.0, 1.0) = 0.0;
// Painted wave shapes: a few short peaked waves (a few metres long) worked
// into the surface's slope per pixel, on top of the swell that moves the
// mesh. How strong (0 is none), the longest one's length in metres, and how
// fast they run.
uniform float paint_waves : hint_range(0.0, 2.0) = 0.0;
uniform float paint_wave_length : hint_range(1.0, 40.0) = 7.0;
uniform float paint_wave_speed : hint_range(0.0, 3.0) = 1.0;
// Cuts the mirrored sky into this many flat steps of brightness, so wave
// faces read as painted strokes (0 is smooth, off).
uniform float reflection_bands : hint_range(0.0, 8.0) = 0.0;
// The least share of the sky the water mirrors, even looking straight
// down, so near wave faces still catch the sky (0 is physical, the night sea).
uniform float reflection_floor : hint_range(0.0, 1.0) = 0.0;
// The long column of sun on the water: its strength (0 is none) and how wide
// it is (as a sideways angle from the camera).
uniform float sun_path : hint_range(0.0, 4.0) = 0.0;
uniform float sun_path_width : hint_range(0.005, 0.3) = 0.06;
// Painted clouds in the mirrored sky (the sky's own clouds can't be read by
// a surface shader): how much, how big, and their lit and shaded colours.
uniform float sky_clouds : hint_range(0.0, 1.0) = 0.0;
uniform float sky_cloud_scale : hint_range(0.05, 4.0) = 0.6;
uniform vec4 sky_cloud_lit : source_color = vec4(0.95, 0.5, 0.33, 1.0);
uniform vec4 sky_cloud_shade : source_color = vec4(0.4, 0.27, 0.5, 1.0);
// The engine's own specular reflection (sun highlight and the blurred sky
// cube map). 0.5 is Godot's default.
uniform float sky_specular : hint_range(0.0, 1.0) = 0.5;

varying vec3 v_world;
varying vec3 v_normal;
varying float v_height;
varying float v_crest;

// Signed distance from the hull's waterline outline (negative inside), in
// metres: a box from the stern forward, then a pointed bow. The outline is a
// polygon, and this is the usual signed distance to a polygon: the nearest
// edge gives the distance, and counting edge crossings gives the sign.
float hull_distance(vec3 world) {
	vec2 p = (hull_inverse * vec4(world, 1.0)).xz;
	float hx = hull_half.x;
	float hz = hull_half.y;
	vec2 v[9] = {
		vec2(hx, hz), vec2(-hx, hz), vec2(-hx, -hz),
		vec2(-hx * 0.87, -hz - bow_reach * 0.48), vec2(-hx * 0.53, -hz - bow_reach * 0.83),
		vec2(0.0, -hz - bow_reach),
		vec2(hx * 0.53, -hz - bow_reach * 0.83), vec2(hx * 0.87, -hz - bow_reach * 0.48),
		vec2(hx, -hz)
	};
	float d = dot(p - v[0], p - v[0]);
	float s = 1.0;
	for (int i = 0; i < 9; i++) {
		int j = (i + 8) % 9;
		vec2 e = v[j] - v[i];
		vec2 w = p - v[i];
		vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
		d = min(d, dot(b, b));
		bvec3 c = bvec3(p.y >= v[i].y, p.y < v[j].y, e.x * w.y > e.y * w.x);
		if (all(c) || all(not(c))) {
			s *= -1.0;
		}
	}
	return s * sqrt(d);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 still = world.xz;
	vec3 moved = vec3(0.0);
	// Slopes of the surface along x (binormal) and z (tangent).
	vec3 binormal = vec3(1.0, 0.0, 0.0);
	vec3 tangent = vec3(0.0, 0.0, 1.0);
	float crest = 0.0;
	for (int i = 0; i < wave_count; i++) {
		vec2 dir = wave_a[i].xy;
		float k = wave_a[i].z;
		float phase = k * (dot(dir, still) - wave_a[i].w * wave_time);
		float amp = wave_b[i].x;
		float side = wave_b[i].y;
		float s = sin(phase);
		float c = cos(phase);
		moved += vec3(dir.x * side * amp * c, amp * s, dir.y * side * amp * c);
		float ka = k * amp;
		binormal += vec3(-side * dir.x * dir.x * ka * s, dir.x * ka * c, -side * dir.x * dir.y * ka * s);
		tangent += vec3(-side * dir.x * dir.y * ka * s, dir.y * ka * c, -side * dir.y * dir.y * ka * s);
		crest += side * ka * s;
	}
	// The mesh is only ever moved, never turned, so a world offset is a local one.
	VERTEX += moved;
	v_world = world + moved;
	v_normal = normalize(cross(tangent, binormal));
	v_height = moved.y;
	v_crest = crest;
}

// A small random number for a grid cell.
float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

// The slope (x, z) of rain rings around [world]: each 1.2 m cell has a drop
// landing at a random time and place, spreading a ring outwards.
vec2 rain_slope(vec2 world, float time) {
	vec2 slope = vec2(0.0);
	float cell_size = 1.2;
	vec2 base = floor(world / cell_size);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 cell = base + vec2(float(x), float(y));
			float seed = hash(cell);
			// Fewer drops land when the rain is lighter.
			if (seed > rain) {
				continue;
			}
			vec2 centre = (cell + vec2(hash(cell + 3.1), hash(cell + 7.7))) * cell_size;
			float age = fract(time * 0.9 + seed * 13.0);
			vec2 to_here = world - centre;
			float dist = length(to_here);
			float ring = age * 0.9;
			float wave = sin((dist - ring) * 28.0) * smoothstep(0.12, 0.0, abs(dist - ring));
			slope += normalize(to_here + 0.0001) * wave * (1.0 - age) * 0.35;
		}
	}
	return slope;
}

// How much light from the Grave of the Lanterns reaches the surface at
// [world], seen from [eye]. The view ray carries on down through the surface
// to three depths, and at each a few seeded spots hold a dying light. Because
// each is found where the ray reaches its depth, the lights sit under the
// water and slide past each other as the camera moves, as deep things do.
float grave_lights(vec3 world, vec3 eye, float time) {
	vec3 ray = normalize(world - eye);
	// Looking flat across the water, nothing below can be seen.
	if (ray.y > -0.08) {
		return 0.0;
	}
	float lit = 0.0;
	for (int layer = 0; layer < 3; layer++) {
		float depth = 5.0 + float(layer) * 7.0;
		vec2 at = world.xz + ray.xz / -ray.y * depth;
		float cell_size = 4.0 + float(layer) * 2.5;
		vec2 base = floor(at / cell_size);
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				vec2 cell = base + vec2(float(x), float(y)) + float(layer) * 31.0;
				float seed = hash(cell);
				if (seed > grave_share) {
					continue;
				}
				vec2 centre = (cell - float(layer) * 31.0
						+ vec2(hash(cell + 1.3), hash(cell + 5.1)) * 0.6 + 0.2) * cell_size;
				float d = length(at - centre);
				float radius = 0.25 + 0.2 * hash(cell + 9.9);
				// A small core, and a wider faint halo from the water around it.
				float glow = exp(-d * d / (radius * radius))
						+ 0.2 * exp(-d * d / (radius * radius * 9.0));
				float gutter = 0.7 + 0.3 * sin(time * (0.8 + seed * 3.0) + seed * 40.0);
				lit += glow * gutter * (1.0 - float(layer) * 0.3);
			}
		}
	}
	return lit;
}

// The dusk sky in direction [r] (world space, unit): the same gradient and
// sun glow as shaders/painted_sky.gdshader, with painted stand-in clouds
// (coral towards the sun, violet away) when [sky_clouds] is on.
vec3 dusk_sky(vec3 r) {
	float h = clamp(r.y, 0.0, 1.0);
	vec3 c = mix(sky_horizon.rgb, sky_mid.rgb, smoothstep(0.0, 0.12, h));
	c = mix(c, sky_zenith.rgb, smoothstep(0.1, 0.7, h));
	float toward = max(dot(r, normalize(sky_sun_direction)), 0.0);
	c += sky_sun_color.rgb * (pow(toward, 24.0) * 0.35 + pow(toward, 120.0) * 1.0);
	if (sky_clouds > 0.0) {
		vec2 plane = r.xz / (h + 0.25) * sky_cloud_scale;
		float blob = texture(foam_noise, plane * 0.15 + vec2(0.3, 0.1)).r * 0.65
				+ texture(foam_noise, plane * 0.4).r * 0.35;
		float cloud = smoothstep(0.5, 0.6, blob) * smoothstep(0.0, 0.08, h);
		vec3 cloud_col = mix(sky_cloud_shade.rgb, sky_cloud_lit.rgb, smoothstep(0.3, 0.9, toward));
		c = mix(c, cloud_col, cloud * sky_clouds);
	}
	return c;
}

// The slope (x, z) of the painted waves at [p]: five short waves with peaked
// crests (exp(sin) makes the crest narrow and the trough broad), their
// positions bent by [warp] so the shapes look drawn rather than ruled.
vec2 painted_wave_slope(vec2 p, vec2 warp, float time) {
	vec2 slope = vec2(0.0);
	float angles[5] = {0.15, -0.3, 0.5, -0.65, 0.02};
	float lengths[5] = {1.0, 0.63, 0.42, 0.31, 0.21};
	float steep[5] = {0.4, 0.3, 0.22, 0.16, 0.1};
	for (int i = 0; i < 5; i++) {
		vec2 dir = vec2(sin(angles[i]), -cos(angles[i]));
		float k = 6.2832 / (paint_wave_length * lengths[i]);
		float phase = k * dot(dir, p + warp * (1.0 + float(i) * 0.4))
				- sqrt(9.8 * k) * time * paint_wave_speed;
		float peak = exp(sin(phase) - 1.0);
		slope += dir * steep[i] * peak * cos(phase);
	}
	return slope;
}

void fragment() {
	float hull_d = hull_distance(v_world);
	// The hull hides the water inside it; cut it out so it can't show
	// through the galley floor as the swell passes.
	if (hull_d < 0.0) {
		discard;
	}

	// The fine chop, from two normal maps drifting different ways.
	vec2 uv = v_world.xz * detail_scale;
	vec3 na = texture(detail_a, uv + vec2(0.02, 0.013) * TIME).xyz * 2.0 - 1.0;
	vec3 nb = texture(detail_b, uv * 1.7 - vec2(0.017, 0.022) * TIME).xyz * 2.0 - 1.0;
	vec2 detail = (na.xy + nb.xy) * detail_strength;
	vec2 rings = rain_slope(v_world.xz, TIME) * rain;
	vec3 n = normalize(v_normal + vec3(detail.x + rings.x, 0.0, detail.y + rings.y));
	if (paint_waves > 0.0) {
		vec2 warp = vec2(texture(foam_noise, v_world.xz * 0.02).r,
				texture(foam_noise, v_world.xz * 0.02 + 0.5).r) * 1.5;
		vec2 waves = painted_wave_slope(v_world.xz, warp, TIME);
		n = normalize(n - vec3(waves.x, 0.0, waves.y) * paint_waves);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// Light glows through the wave where the surface is high and thin.
	float glow = clamp(v_height * 0.35 + 0.2, 0.0, 1.0) * clamp(v_crest * 2.0 + 0.4, 0.0, 1.0);
	vec3 water = mix(deep_color.rgb, crest_color.rgb, glow);

	// Foam: on sharp crests, hugging the hull, and trailing behind the ship.
	float noise = texture(foam_noise, v_world.xz * 0.08 + vec2(0.0, TIME * 0.03)).r;
	float foam = smoothstep(crest_foam_from, 1.0, v_crest + noise * 0.25);
	vec2 local = (hull_inverse * vec4(v_world, 1.0)).xz;
	// Under way, the bow shoulders the water aside in a wider wave of foam.
	float at_bow = smoothstep(-hull_half.y + 3.0, -hull_half.y - bow_reach, local.y);
	float band_width = hull_foam_width * (1.0 + bow_wave * wake * at_bow);
	float hull_band = 1.0 - smoothstep(0.0, band_width, hull_d);
	foam = max(foam, hull_band * smoothstep(0.25, 0.75, noise + 0.25));
	float stirred = hull_band;
	float behind = local.y - hull_half.y;
	if (behind > -1.0 && wake > 0.0) {
		// The wake (#203). Its foam is laid on the water where the ship
		// passed, so it's patterned in the world's space, not the ship's: it
		// stays where it fell and the ship draws away from it, instead of
		// dragging the same stripes along behind her. The newest is a churned
		// band straight astern; it widens, thins and breaks into patches as
		// it ages, and two faint arms spread out at an angle either side.
		float aft = max(behind, 0.0);
		float age = clamp(aft / wake_length, 0.0, 1.0);
		float coarse = texture(foam_noise, v_world.xz * 0.09 + vec2(TIME * 0.006, 0.0)).r;
		float fine = texture(foam_noise, v_world.xz * 0.31 - vec2(0.0, TIME * 0.015)).r;
		float churn = coarse * 0.6 + fine * 0.4;
		float half_width = hull_half.x * (0.45 + aft * 0.045);
		float across = 1.0 - smoothstep(half_width * 0.3, half_width, abs(local.x));
		float band = across * smoothstep(0.38 + age * 0.3, 0.64 + age * 0.3, churn) * 0.8
				* (1.0 - smoothstep(0.55, 1.0, age));
		float arm_out = hull_half.x * 0.75 + aft * 0.34;
		float arm_off = abs(abs(local.x) - arm_out);
		float arm = (1.0 - smoothstep(0.0, 0.35 + aft * 0.02, arm_off))
				* smoothstep(0.4, 0.7, fine + 0.1) * (1.0 - smoothstep(0.15, 0.9, age)) * 0.4;
		float from_stern = smoothstep(-1.0, 1.5, behind);
		float wake_foam = max(band, arm) * wake * from_stern;
		foam = max(foam, wake_foam);
		stirred = max(stirred, across * (1.0 - age) * wake * from_stern);
	}
	// Painted foam: the soft edge is cut to a narrow one.
	foam = mix(foam, smoothstep(0.42, 0.5, foam), foam_crisp);
	// Where the water's been stirred, tiny specks glint and fade.
	float specks = texture(foam_noise, v_world.xz * 1.3 + vec2(TIME * 0.11, -TIME * 0.07)).r;
	float twinkle = smoothstep(0.7, 0.78, specks) * (0.6 + 0.4 * sin(TIME * 3.0 + specks * 40.0));
	float glints = twinkle * stirred * foam;

	ALBEDO = mix(water, foam_color.rgb, foam);
	// A night sea has almost no light on it, so crests and foam glow a
	// little on their own, the way painted night seas do; otherwise the swell
	// would vanish into black.
	// Water mirrors the sky at a glancing angle and looks dark head-on. The
	// night sky is nearly black, so the misty sky colour is added by hand,
	// which is what lets the swell's shape read against the fog.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	fresnel = mix(reflection_floor, 1.0, fresnel);
	if (reflection_bands > 0.0) {
		// Painted: a few flat steps, each edge softened a touch.
		float x = fresnel * reflection_bands;
		fresnel = (floor(x) + smoothstep(0.35, 0.65, fract(x))) / reflection_bands;
	}
	vec3 to_surface = normalize(v_world - CAMERA_POSITION_WORLD);
	vec3 mirrored = reflect(to_surface, n);
	mirrored.y = abs(mirrored.y);
	vec3 sky_colour = mix(sky_reflection.rgb, dusk_sky(mirrored), reflect_sky);
	vec3 sky = sky_colour * fresnel * (1.0 - foam);
	EMISSION = sky + crest_color.rgb * glow * night_glow
			+ foam_color.rgb * foam * night_glow * 0.35
			+ glimmer_color.rgb * glints * glimmer;
	// Before the sun's light, so the sun path still reaches the horizon.
	if (far_blend > 0.0) {
		float far = smoothstep(far_start, far_end, length(v_world - CAMERA_POSITION_WORLD)) * far_blend;
		ALBEDO = mix(ALBEDO, far_color.rgb, far);
		EMISSION = mix(EMISSION, far_color.rgb * 0.7, far);
	}
	vec3 sun_dir = normalize(sky_sun_direction);
	vec2 sun_flat = normalize(sun_dir.xz + vec2(0.0001));
	if (glitter > 0.0) {
		// The sun's glints. Each wave face is a little mirror; it flashes
		// when it throws the view towards the sun. The test is stretched
		// (anisotropic): tight sideways (the bearing must match the sun's),
		// loose up and down (any tilt along the line to the sun will do),
		// which draws the glitter out into a long column under a low sun.
		vec2 bounce_flat = normalize(mirrored.xz + vec2(0.0001));
		float sideways = abs(bounce_flat.x * sun_flat.y - bounce_flat.y * sun_flat.x);
		float facing = step(0.0, dot(bounce_flat, sun_flat));
		float upright = abs(mirrored.y - sun_dir.y);
		float side_tol = 0.03 + 0.12 * glitter_width;
		float streak = (1.0 - smoothstep(side_tol * 0.3, side_tol, sideways))
				* (1.0 - smoothstep(0.06, 0.3, upright)) * facing;
		float dashes = texture(foam_noise, v_world.xz * vec2(0.7, 0.22) + vec2(TIME * 0.02, 0.0)).r;
		float broken = smoothstep(0.4, 0.52, dashes + detail.x * 0.4);
		// Painted: two flat steps, not a smooth falloff.
		float steps = floor(streak * 3.0) / 3.0 + step(0.66, streak) * 0.34;
		EMISSION += glitter_color.rgb * glitter * steps * broken * (1.0 - foam);
	}
	if (sun_path > 0.0) {
		// A softer sheen along the same column, so the dashes sit in a glow.
		// Measured from the camera's bearing to this spot, so it lies under
		// the sun whichever way the camera turns; the wave faces tilted
		// towards the sun catch more of it.
		vec2 look_flat = normalize(to_surface.xz + vec2(0.0001));
		float off = abs(look_flat.x * sun_flat.y - look_flat.y * sun_flat.x);
		float ahead = step(0.0, dot(look_flat, sun_flat));
		float column = exp(-pow(off / sun_path_width, 2.0)) * ahead;
		// Painted: the faces turned to the sun take it in two flat steps.
		// Far off the faces are too small to see apart, so the path there is
		// solid, and brighter, as a real one is towards the horizon.
		float dist = length(v_world - CAMERA_POSITION_WORLD);
		float far_path = smoothstep(30.0, 300.0, dist);
		float face = clamp(dot(n.xz, sun_flat) * 5.0 + 0.3, 0.0, 1.0);
		face = smoothstep(0.25, 0.35, face) * 0.4 + smoothstep(0.65, 0.75, face) * 0.6;
		face = mix(face, 1.0, far_path * 0.7);
		column *= 0.6 + far_path * 0.8;
		EMISSION += glitter_color.rgb * sun_path * column * (0.1 + 0.9 * face) * (1.0 - foam);
	}
	if (grave > 0.0) {
		// Seen through the water, so foam and the mirrored sky hide them.
		EMISSION += grave_color.rgb * grave_lights(v_world, CAMERA_POSITION_WORLD, TIME)
				* grave * grave_energy * (1.0 - foam) * (1.0 - fresnel);
	}
	ROUGHNESS = mix(roughness_water, 0.85, foam);
	METALLIC = 0.0;
	SPECULAR = sky_specular;
}

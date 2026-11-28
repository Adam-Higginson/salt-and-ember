// Where spray is blown off the sea (SeaSpray, scripts/sea/sea_spray.gd): a
// particle process shader, run on the graphics card for every droplet.
//
// The droplets come in little bursts. Every [burst_seconds] each burst slot
// picks a spot near the boat (or beside a post standing in the water) and
// works out the waves there with the same Gerstner maths as the water
// (water.gdshaderinc, scripts/sea/waves.gd). Only where a crest is pointed
// enough (or, at a post, the water is rising round it) do its droplets
// fly; elsewhere they're switched off at once, so nothing is drawn. Those
// that fly start on the surface, lift and are blown along the wave, then
// fall back and fade.
shader_type particles;

// The waves, as the Sea hands them to the water (Sea.apply_waves_to).
uniform int wave_count = 0;
uniform vec4 wave_a[4];
uniform vec4 wave_b[4];
uniform float wave_time = 0.0;
// The sea's still level (its node's height) and where the spray gathers.
uniform float sea_level = 0.0;
uniform vec2 centre = vec2(0.0);
uniform float radius = 14.0;
// How pointed a crest must be before spray comes off it (0 to 1, the same
// scale as the water's crest foam).
uniform float crest_from = 0.55;
// Up to eight posts standing in the water (the jetty's piles): x, z, radius.
uniform int post_count = 0;
uniform vec3 posts[8];
// The share of bursts that go to the posts, and how high the water must have
// risen round one (in metres above still) before it splashes.
uniform float post_share : hint_range(0.0, 1.0) = 0.3;
uniform float post_from = 0.15;
// How often the bursts move on, and how many slots there are.
uniform float burst_seconds = 0.35;
uniform int bursts = 6;
// How fast droplets lift and are blown along, in metres a second, and how
// hard they fall.
uniform float lift = 1.7;
uniform float blow = 1.4;
uniform float gravity = 5.5;
// How big a droplet is, smallest to biggest, in metres.
uniform vec2 sizes = vec2(0.08, 0.22);

float hash(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 0x7fffffffu) / float(0x7fffffff);
}

// The surface point the still-water point [still] is carried to, and how
// pointed the crest is there (in .w).
vec4 surface(vec2 still) {
	vec3 moved = vec3(0.0);
	float crest = 0.0;
	for (int i = 0; i < wave_count; i++) {
		vec2 dir = wave_a[i].xy;
		float k = wave_a[i].z;
		float phase = k * (dot(dir, still) - wave_a[i].w * wave_time);
		float amp = wave_b[i].x;
		float side = wave_b[i].y;
		moved += vec3(dir.x * side * amp * cos(phase), amp * sin(phase), dir.y * side * amp * cos(phase));
		crest += side * k * amp * sin(phase);
	}
	return vec4(still.x + moved.x, sea_level + moved.y, still.y + moved.z, crest);
}

// The way the most peaked layer rolls: the way spray is blown.
vec2 blown() {
	vec2 dir = vec2(0.0, -1.0);
	float most = -1.0;
	for (int i = 0; i < wave_count; i++) {
		float peak = wave_b[i].y * wave_a[i].z * wave_b[i].x;
		if (peak > most) {
			most = peak;
			dir = wave_a[i].xy;
		}
	}
	return dir;
}

void start() {
	if (RESTART_POSITION) {
		// Which burst this droplet belongs to, and that burst's moment.
		uint slot = uint(NUMBER) % uint(max(bursts, 1));
		uint moment = uint(floor(TIME / burst_seconds));
		uint burst_seed = moment * 92821u + slot * 6151u;
		uint own_seed = uint(NUMBER) * 1973u + RANDOM_SEED;
		bool at_post = post_count > 0 && hash(burst_seed + 7u) < post_share;
		vec2 spot;
		float wanted;
		if (at_post) {
			int which = int(hash(burst_seed + 11u) * float(post_count)) % post_count;
			vec3 post = posts[which];
			float angle = hash(own_seed + 3u) * 6.2832;
			spot = post.xy + vec2(cos(angle), sin(angle)) * (post.z + 0.05);
			wanted = post_from;
		} else {
			float angle = hash(burst_seed + 1u) * 6.2832;
			float out_by = sqrt(hash(burst_seed + 2u)) * radius;
			spot = centre + vec2(cos(angle), sin(angle)) * out_by
					+ (vec2(hash(own_seed + 5u), hash(own_seed + 9u)) - 0.5) * 0.9;
			wanted = crest_from;
		}
		vec4 here = surface(spot);
		float test = at_post ? here.y - sea_level : here.w;
		if (test < wanted) {
			ACTIVE = false;
		} else {
			float size = mix(sizes.x, sizes.y, hash(own_seed + 13u));
			TRANSFORM = mat4(1.0);
			TRANSFORM[3].xyz = here.xyz;
			vec2 along = blown();
			float strength = 0.5 + hash(own_seed + 17u);
			vec2 scatter = (vec2(hash(own_seed + 19u), hash(own_seed + 23u)) - 0.5) * 0.8;
			VELOCITY = vec3((along * blow + scatter) * strength, lift * (0.6 + 0.8 * hash(own_seed + 29u)));
			if (at_post) {
				// Thrown up the post, a little out from it.
				VELOCITY = vec3(scatter * 0.8, lift * 1.2 * strength);
			}
			// x: size, y: life so far (0 to 1), z: a random spin.
			CUSTOM = vec4(size, 0.0, hash(own_seed + 31u) * 6.2832, 0.0);
			COLOR = vec4(1.0);
		}
	}
}

void process() {
	VELOCITY.y -= gravity * DELTA;
	VELOCITY.xz *= 1.0 - 0.6 * DELTA;
	CUSTOM.y = clamp(CUSTOM.y + DELTA / LIFETIME, 0.0, 1.0);
	// Fades in quickly, out slowly; gone once it falls back in.
	COLOR.a = smoothstep(0.0, 0.1, CUSTOM.y) * (1.0 - smoothstep(0.5, 1.0, CUSTOM.y));
	if (TRANSFORM[3].y < sea_level - 1.2) {
		ACTIVE = false;
	}
}

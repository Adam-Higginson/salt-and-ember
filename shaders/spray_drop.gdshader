// One droplet of sea spray (SeaSpray): a little painted dab that always faces
// the camera, pale and cool, warming to the sun's colour on the side of the
// view the sun is on, as spray catches a low sun. Its size, age and spin come
// from the process shader (shaders/sea_spray.gdshader) in INSTANCE_CUSTOM.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 cool_color : source_color = vec4(0.62, 0.6, 0.78, 1.0);
uniform vec4 warm_color : source_color = vec4(1.0, 0.68, 0.38, 1.0);
// The direction towards the sun, as in the water's material.
uniform vec3 sun_direction = vec3(-0.37, 0.055, -0.93);
// How strong the dabs are overall.
uniform float strength : hint_range(0.0, 2.0) = 0.8;
// A noise for the ragged edge of each dab.
uniform sampler2D dab_noise : filter_linear, repeat_enable;

varying float v_sunward;
varying float v_spin;

void vertex() {
	// Face the camera, at the droplet's own size.
	float size = INSTANCE_CUSTOM.x;
	mat4 facing = mat4(
		vec4(normalize(INV_VIEW_MATRIX[0].xyz) * size, 0.0),
		vec4(normalize(INV_VIEW_MATRIX[1].xyz) * size, 0.0),
		vec4(normalize(INV_VIEW_MATRIX[2].xyz) * size, 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	vec3 from_eye = MODEL_MATRIX[3].xyz - CAMERA_POSITION_WORLD;
	v_sunward = max(dot(normalize(from_eye.xz + vec2(0.0001)),
			normalize(sun_direction.xz + vec2(0.0001))), 0.0);
	v_spin = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec2 p = UV - 0.5;
	float c = cos(v_spin);
	float s = sin(v_spin);
	p = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	// A dab: a soft disc with a ragged, brushed edge.
	float ragged = texture(dab_noise, p * 0.6 + v_spin).r;
	float dab = 1.0 - smoothstep(0.26, 0.48, length(p * vec2(1.0, 1.4)) + (ragged - 0.5) * 0.25);
	vec3 colour = mix(cool_color.rgb, warm_color.rgb, v_sunward * v_sunward);
	ALBEDO = colour * (0.8 + 0.6 * v_sunward * v_sunward);
	ALPHA = dab * COLOR.a * strength;
}

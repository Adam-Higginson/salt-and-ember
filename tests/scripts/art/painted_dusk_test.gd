extends GameTestSuite
## Tests for the painted dusk (home waters' sky, grade and water). The sea
## shader is shared with the night scenes (the Grave, the ship's sea), so its
## dusk dials must all default to "off" and the night material must not set
## them; and home waters must use the dusk resources.

const WATER_SHADER: Shader = preload("res://shaders/water.gdshader")
const NIGHT_WATER: ShaderMaterial = preload("res://assets/placeholder/materials/water.tres")
const DUSK_WATER: ShaderMaterial = preload("res://assets/placeholder/materials/water_dusk.tres")
const HOME_SCENE: String = "res://scenes/prototype/intro/home_waters.tscn"
## The dusk dials: each one's default must switch its effect off.
const DUSK_DIALS: Array[StringName] = [
	&"reflect_sky", &"glitter", &"far_blend", &"foam_crisp", &"paint_waves",
	&"reflection_bands", &"reflection_floor", &"sun_path", &"sky_clouds",
]


func test_the_water_shaders_dusk_dials_default_to_off() -> void:
	# A shader's defaults live in its code, so read them from there.
	for dial: StringName in DUSK_DIALS:
		assert_str(_default_of(dial)).is_equal("0.0")
	# Same Fresnel power and engine specular as before the dusk work.
	assert_str(_default_of(&"fresnel_power")).is_equal("4.0")
	assert_str(_default_of(&"sky_specular")).is_equal("0.5")


func test_the_night_water_does_not_set_the_dusk_dials() -> void:
	for dial: StringName in DUSK_DIALS:
		assert_object(NIGHT_WATER.get_shader_parameter(dial)).is_null()
	assert_object(NIGHT_WATER.get_shader_parameter(&"fresnel_power")).is_null()
	assert_object(NIGHT_WATER.get_shader_parameter(&"sky_specular")).is_null()


func test_the_dusk_water_turns_them_on() -> void:
	for dial: StringName in DUSK_DIALS:
		assert_float(DUSK_WATER.get_shader_parameter(dial)).is_greater(0.0)


func test_home_waters_uses_the_dusk_environment_and_sea() -> void:
	var runner: GdUnitSceneRunner = scene_runner(HOME_SCENE)
	var beat: HomeWaters = runner.scene() as HomeWaters
	var env: Environment = beat.world.environment
	var sky: Sky = env.sky
	assert_object(sky).is_not_null()
	var material: ShaderMaterial = sky.sky_material as ShaderMaterial
	assert_str(material.shader.resource_path).is_equal("res://shaders/painted_sky.gdshader")
	# Drifting clouds only need the ambient light updating slowly.
	assert_int(sky.process_mode).is_equal(Sky.PROCESS_MODE_INCREMENTAL)
	# The raymarched cumulus are drawn at half resolution, cut from two 3D noises.
	assert_str(material.shader.code).contains("render_mode use_half_res_pass;")
	assert_object(material.get_shader_parameter(&"cloud_shape")).is_instanceof(NoiseTexture3D)
	assert_object(material.get_shader_parameter(&"cloud_puffs")).is_instanceof(NoiseTexture3D)
	var sea: MeshInstance3D = beat.sea
	assert_object(sea.material_override).is_same(DUSK_WATER)


# The text after "=" on the water shader's "uniform <type> <name> ... = <value>;".
func _default_of(uniform_name: StringName) -> String:
	var pattern: RegEx = RegEx.create_from_string(
			"uniform\\s+\\w+\\s+" + String(uniform_name) + "\\b[^=;]*=\\s*([^;]+);")
	var found: RegExMatch = pattern.search(WATER_SHADER.code)
	assert_object(found).is_not_null()
	return found.get_string(1).strip_edges()

class_name HomeIslandShape
extends RefCounted
## The shape of the player's home island, as numbers: how high the ground is at
## any spot (x, z in metres), where the stone path runs and where the shingle
## cove is. [code]tools/terrain/build_home_island.gd[/code] samples it into the
## terrain's heightmap, so changing a number here and running the tool again
## re-sculpts the island. It's a plain class with no Terrain3D in it, so it
## can be tested and changed without the plugin.
##
## The island is a cone (the old greybox hill) turned into tiers: gently
## sloping grassy treads with steep rock risers between them, so from the water
## it reads as grassy shoulders on layered cliffs. Then, in this order, flat
## terraces for the cottages and the summit, the winding path's cut, the
## beach by the jetty, the shingle cove and the rocks at the waterline are
## laid on top. Every prop in [code]home_waters.tscn[/code] keeps its old
## position, so the terraces and the path are pinned to the heights those
## props stand at.

## The middle of the island, where the summit and the mooring are.
const CENTRE: Vector2 = Vector2(0.0, 70.0)
## The sea floor: deep enough that the sea surface hides the terrain's edge.
const SEA_FLOOR: float = -30.0
## The summit's height, which the mooring stands on.
const SUMMIT: float = 34.0
## Out to this radius the summit is a flat plateau.
const PLATEAU_RADIUS: float = 8.5
## The cone reaches the sea at about this radius (varied round the island).
const SHORE_RADIUS: float = 36.0
## How steep the cone is, before it is cut into tiers (the old hill's slope).
const CONE_SLOPE: float = 1.095
## How tall each tier is.
const TIER: float = 6.0
## Where the stone path starts to blend back into the hillside, in metres.
const PATH_HALF_WIDTH: float = 1.4
const PATH_FADE: float = 2.6

## Flat shelves for the buildings: x, z, ground height, half width, half depth,
## yaw (radians). The size is the building's footprint, a little over.
const SHELVES: Array[Dictionary] = [
	{"name": "JettyCottage", "pos": Vector3(29, 1.6, 45), "half": Vector2(4.6, 3.8), "yaw": 3.14159},
	{"name": "Cottage2", "pos": Vector3(14, 8.5438, 46), "half": Vector2(4.0, 3.4), "yaw": 2.6337},
	{"name": "Cottage3", "pos": Vector3(-14, 12.3109, 50), "half": Vector2(4.0, 3.4), "yaw": -2.54},
	{"name": "Cottage4", "pos": Vector3(22, 14.1092, 64), "half": Vector2(4.0, 3.4), "yaw": 1.8386},
	{"name": "Cottage5", "pos": Vector3(-6, 22.5689, 56), "half": Vector2(4.0, 3.4), "yaw": -2.7314},
	{"name": "Cottage6", "pos": Vector3(10, 26.557, 76), "half": Vector2(4.0, 3.4), "yaw": 1.0306},
]
## How far a shelf's edge takes to blend into the hillside.
const SHELF_FADE: float = 3.2

## The winding path, as polylines of (x, height, z) points: the lamp posts'
## positions and heights are on it, the cottages' doors are at its ends. The
## first is the main way up from the jetty to the mooring; the rest branch off.
static var paths: Array[PackedVector3Array] = [
	# From the jetty to the summit.
	PackedVector3Array([Vector3(25.5, 1.6, 37.0), Vector3(21.5, 1.6, 38.5), Vector3(19.0, 3.2, 41.5),
	Vector3(17.0, 4.88, 44.0), Vector3(14.5, 6.2, 41.5), Vector3(10.5, 8.8, 42.0),
	Vector3(8.0, 12.38, 47.0),
	Vector3(2.5, 16.0, 49.5), Vector3(-3.0, 19.2, 52.0), Vector3(-3.5, 22.57, 55.2),
	Vector3(-2.0, 26.5, 59.5), Vector3(0.0, 31.0, 61.5), Vector3(0.0, 34.0, 64.0)]),
	# Along the hillside to the third cottage.
	PackedVector3Array([Vector3(8.0, 12.38, 47.0), Vector3(3.0, 12.31, 46.2), Vector3(-4.0, 12.31, 47.0),
	Vector3(-10.0, 12.31, 48.0), Vector3(-11.5, 12.31, 50.0)]),
	# From the second cottage up to the fourth.
	PackedVector3Array([Vector3(16.5, 8.55, 46.3), Vector3(18.0, 9.2, 50.0), Vector3(20.5, 11.2, 55.0),
	Vector3(21.5, 13.4, 60.0), Vector3(21.0, 14.11, 62.0)]),
	# From the fourth cottage to the sixth, and on to the summit.
	PackedVector3Array([Vector3(21.0, 14.11, 65.5), Vector3(19.5, 16.8, 68.0), Vector3(16.5, 20.5, 71.0),
	Vector3(14.5, 24.0, 70.8), Vector3(11.0, 26.56, 69.5), Vector3(6.5, 31.0, 70.2),
	Vector3(3.5, 33.8, 70.5)]),
]

## Sea stacks and boulders at the waterline: x, z, radius, height above the
## sea. The old greybox's four rocks come first.
const ROCKS: Array[Vector4] = [
	Vector4(-30, 40, 5.5, 4.5), Vector4(-38, 62, 5.5, 5.0), Vector4(36, 78, 5.5, 4.2),
	Vector4(6, 30, 4.5, 3.0),
]
## How many more boulders to scatter round the shore, and the seed that places them.
const SCATTER_COUNT: int = 30
const SCATTER_SEED: int = 7

## Where the shingle cove is, and the beach by the jetty: centre, half sizes.
const COVE_CENTRE: Vector2 = Vector2(12.5, 38.5)
const COVE_HALF: Vector2 = Vector2(7.5, 5.5)
const BEACH_CENTRE: Vector2 = Vector2(28.0, 41.5)
const BEACH_HALF: Vector2 = Vector2(10.0, 8.5)
## Where the boat and the jetty are: no boulders within this of it.
const JETTY_LANE: Vector2 = Vector2(26.0, 32.0)
const JETTY_LANE_RADIUS: float = 16.0

var _warp: FastNoiseLite = FastNoiseLite.new()
var _detail: FastNoiseLite = FastNoiseLite.new()
var _ridges: FastNoiseLite = FastNoiseLite.new()
var _outline: FastNoiseLite = FastNoiseLite.new()
var _rocks: Array[Vector4] = []
## Each path segment as (x1, z1, x2, z2) and its heights (y1, y2).
var _segments: Array[Vector4] = []
var _segment_heights: Array[Vector2] = []


func _init() -> void:
	_warp.seed = 11
	_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp.fractal_type = FastNoiseLite.FRACTAL_FBM
	_warp.fractal_octaves = 3
	_warp.frequency = 0.045
	_detail.seed = 23
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 0.16
	_ridges.seed = 5
	_ridges.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridges.fractal_octaves = 3
	_ridges.frequency = 0.22
	_outline.seed = 3
	_outline.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_outline.frequency = 0.9
	_rocks.assign(ROCKS)
	_scatter_rocks()
	for path: PackedVector3Array in paths:
		for i: int in path.size() - 1:
			var a: Vector3 = path[i]
			var b: Vector3 = path[i + 1]
			_segments.append(Vector4(a.x, a.z, b.x, b.z))
			_segment_heights.append(Vector2(a.y, b.y))


## The ground's height at (x, z): above 0 is land, below is the sea floor.
func height_at(x: float, z: float) -> float:
	var h: float = _base_height(x, z)
	h = _lay_beach_and_cove(x, z, h)
	h = _lay_shelves(x, z, h)
	h = _lay_path(x, z, h)
	h = maxf(h, _rock_height(x, z))
	return maxf(h, SEA_FLOOR)


## How far (x, z) is from the nearest bit of path, in metres, and the path's
## height there: x is the distance, y the height.
func path_at(x: float, z: float) -> Vector2:
	var best: float = INF
	var best_h: float = 0.0
	var p: Vector2 = Vector2(x, z)
	for i: int in _segments.size():
		var s: Vector4 = _segments[i]
		var a: Vector2 = Vector2(s.x, s.y)
		var ab: Vector2 = Vector2(s.z, s.w) - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d: float = p.distance_to(a + ab * t)
		if d < best:
			best = d
			var heights: Vector2 = _segment_heights[i]
			best_h = lerpf(heights.x, heights.y, t)
	return Vector2(best, best_h)


## 1 inside the shingle cove or the beach, fading to 0 at their edges, for
## painting them shingle.
func shingle_at(x: float, z: float) -> float:
	var cove: float = 1.0 - _ellipse(x, z, COVE_CENTRE, COVE_HALF)
	# The beach is shingle only down by the water: grass grows up to the cottage.
	var beach: float = (1.0 - _ellipse(x, z, BEACH_CENTRE, BEACH_HALF)) * smoothstep(45.0, 40.0, z)
	return clampf(maxf(cove, beach) * 2.2, 0.0, 1.0)


## The scattered boulders and the old rocks: x, z, radius, height.
func rocks() -> Array[Vector4]:
	return _rocks


## A shelf's yaw and half size in its own turned frame, for tests and for
## painting: how far (x, z) is outside the shelf's edge (0 or less is on it).
func outside_shelf(index: int, x: float, z: float) -> float:
	var shelf: Dictionary = SHELVES[index]
	var pos: Vector3 = shelf["pos"]
	var half: Vector2 = shelf["half"]
	var yaw: float = shelf["yaw"]
	var local: Vector2 = Vector2(x - pos.x, z - pos.z).rotated(yaw)
	var out: Vector2 = Vector2(absf(local.x) - half.x, absf(local.y) - half.y)
	return Vector2(maxf(out.x, 0.0), maxf(out.y, 0.0)).length()


func _base_height(x: float, z: float) -> float:
	var away: Vector2 = Vector2(x, z) - CENTRE
	var radius: float = away.length()
	var angle: float = atan2(away.y, away.x)
	var shore: float = SHORE_RADIUS + _shore_offset(angle)
	var scaled: float = radius * SHORE_RADIUS / shore
	var cone: float = SUMMIT - (scaled - 5.0) * CONE_SLOPE
	if cone <= 0.0:
		# Below the sea: a floor that falls away steadily.
		return maxf(SEA_FLOOR, cone * 0.8)
	# Wobbling the height before tiering makes the tiers wander.
	var wobble: float = _warp.get_noise_2d(x, z) * 9.0 * clampf(cone / 6.0, 0.0, 1.0)
	var tiered: float = _tier(clampf(cone + wobble, 0.0, SUMMIT))
	# The tier's flat edge, so rock detail goes on the steep part only.
	var fraction: float = fposmod((cone + wobble) / TIER, 1.0)
	var steep: float = smoothstep(0.62, 0.95, fraction)
	var height: float = tiered
	height += _detail.get_noise_2d(x, z) * (0.35 + 0.5 * steep)
	height += (_ridges.get_noise_2d(x * 1.3, z * 1.3) + 0.4) * 1.1 * steep
	# Ease the very top into the flat summit.
	var top: float = smoothstep(PLATEAU_RADIUS + 5.0, PLATEAU_RADIUS, radius)
	height = lerpf(height, SUMMIT, top)
	return height


## The tiered height for an input height: gentle treads, steep risers.
func _tier(h: float) -> float:
	var k: float = floorf(h / TIER)
	var f: float = h / TIER - k
	var g: float = 0.3 * f + 0.7 * smoothstep(0.62, 0.95, f)
	return TIER * (k + g)


## How far the shore is from its average radius at [param angle], in metres:
## a little wandering, and a bulge where the jetty and the beach are.
func _shore_offset(angle: float) -> float:
	var round_noise: float = _outline.get_noise_2d(cos(angle) * 3.0, sin(angle) * 3.0) * 3.2
	var to_beach: float = angle_difference(angle, -0.71)
	var bulge: float = 7.0 * exp(-to_beach * to_beach / (2.0 * 0.3 * 0.3))
	return round_noise + bulge


func _lay_beach_and_cove(x: float, z: float, h: float) -> float:
	# The beach: flat above the tide, running down into the sea.
	var beach: float = 1.0 - smoothstep(0.55, 1.0, _ellipse(x, z, BEACH_CENTRE, BEACH_HALF))
	var beach_h: float = lerpf(-4.0, 1.6, smoothstep(30.0, 38.5, z))
	h = lerpf(h, beach_h, beach)
	# The cove: a gently sloping bank of shingle between cliffs.
	var cove: float = 1.0 - smoothstep(0.5, 1.0, _ellipse(x, z, COVE_CENTRE, COVE_HALF))
	var cove_h: float = lerpf(-2.5, 1.3, smoothstep(33.0, 41.5, z))
	return lerpf(h, cove_h, cove)


func _lay_shelves(x: float, z: float, h: float) -> float:
	for i: int in SHELVES.size():
		var shelf: Dictionary = SHELVES[i]
		var pos: Vector3 = shelf["pos"]
		var out: float = outside_shelf(i, x, z)
		var weight: float = 1.0 - smoothstep(0.0, SHELF_FADE, out)
		if weight > 0.0:
			h = lerpf(h, pos.y, weight)
	# The summit's flat plateau, under the mooring.
	var plateau: float = 1.0 - smoothstep(PLATEAU_RADIUS - 2.0, PLATEAU_RADIUS + 3.0,
			Vector2(x, z).distance_to(CENTRE))
	return lerpf(h, SUMMIT, plateau)


func _lay_path(x: float, z: float, h: float) -> float:
	var near: Vector2 = path_at(x, z)
	var weight: float = 1.0 - smoothstep(PATH_HALF_WIDTH, PATH_HALF_WIDTH + PATH_FADE, near.x)
	return lerpf(h, near.y, weight) if weight > 0.0 else h


func _rock_height(x: float, z: float) -> float:
	var best: float = SEA_FLOOR
	for rock: Vector4 in _rocks:
		var d: float = Vector2(x - rock.x, z - rock.y).length() / rock.z
		if d >= 1.0:
			continue
		# A rounded stack with a rough, ridged top.
		var bump: float = pow(1.0 - d * d, 0.6) * rock.w
		bump += _ridges.get_noise_2d(x * 2.0, z * 2.0) * 0.25 * rock.w * (1.0 - d)
		best = maxf(best, bump - 1.2)
	return best


func _scatter_rocks() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SCATTER_SEED
	var placed: int = 0
	var tries: int = 0
	while placed < SCATTER_COUNT and tries < 2000:
		tries += 1
		var angle: float = rng.randf_range(-PI, PI)
		var radius: float = SHORE_RADIUS + _shore_offset(angle) + rng.randf_range(-2.0, 7.0)
		var at: Vector2 = CENTRE + Vector2(cos(angle), sin(angle)) * radius
		if at.distance_to(JETTY_LANE) < JETTY_LANE_RADIUS:
			continue
		if _ellipse(at.x, at.y, COVE_CENTRE, COVE_HALF * 1.5) < 1.0:
			continue
		var size: float = rng.randf_range(1.6, 4.2)
		_rocks.append(Vector4(at.x, at.y, size, size * rng.randf_range(0.7, 1.3) + 0.8))
		placed += 1


## Distance from [param centre] in units of [param half], so 1 is the edge of
## the ellipse.
func _ellipse(x: float, z: float, centre: Vector2, half: Vector2) -> float:
	return Vector2((x - centre.x) / half.x, (z - centre.y) / half.y).length()

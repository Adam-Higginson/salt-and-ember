# The stylised look: how to tune it

The game uses a warm, painted, anime-styled look with low golden light through windows, glowing lanterns, warm shadows, and characters with soft cel shading, a rim of light and a thin dark outline. This page says where each part of that look lives and which number to turn for each effect. It started with the look-dev cabin (#168).

## Where to try it

Open `scenes/tools/look_dev_cabin.tscn` and press **F6** (run this scene). The buttons at the top left switch, while it runs:

- **Stylised characters**: the heron and the boy drawn with the stylised shader, or as made.
- **Outlines**: the dark outline on or off.
- **Golden cabin light**: the golden-hour cabin, or plain grey studio light that shows the models as they come.

The buttons change a copy of the style, so they never change the saved files. To tune for real, edit the files below in the Inspector: the cabin shows the changes in the editor viewport straight away, without running.

To photograph every shot in every treatment (for comparing before and after):

```bash
C:/Godot/godot_console.exe --path . --resolution 1600x900 res://scenes/tools/look_dev_cabin.tscn -- --capture=C:/somewhere/captures
```

## What lives where

| Part | File | What it is |
|---|---|---|
| Character shading and outline | `data/art/styles/character.tres` (a `CharacterStyle`) | One shared look for every stylised character. |
| The shader behind it | `shaders/stylised_character.gdshader`, `shaders/outline.gdshader` | Set from the style; you don't edit these to tune. |
| Which characters use it | the `style` slot on each `ThirdPartyModel` | Empty draws the model as made. |
| The cabin's light, fog and post-processing | `data/art/environments/golden_cabin.tres` (an `Environment`) | Ambient light, tone mapping, SSAO, glow, volumetric fog. |
| The sun | the `Sun` node in the cabin | Its colour, energy and shadow. |
| The lanterns | `Lanterns/*/Lamp` (light) and `Lanterns/*/Glow` (`PaintedGlow`) | The light they cast, and how their painted glass glows. |

## Turning the dials

### Shadow bands and thresholds

In `character.tres`, group **Shading**:

- **Shadow Threshold** (-1 to 1, default 0.05): where light turns to shadow. 0 puts the edge exactly side-on to the light; raise it to push more of the body into shadow (moodier, stronger shapes), lower it for more light.
- **Bands** (1 to 4, default 1): 1 is two-tone, soft anime. 3 or 4 gives stepped Wind Waker-style shading.
- **Lit Falloff** (0 to 1, default 0.35): how much the lit side still dims as it turns away from the light. 0 is flat cel colour; higher keeps some roundness inside the light.

### Shadow softness

- **Shadow Softness** (in **Shading**, 0 to 0.5, default 0.04): how soft the light/shadow edge is on the character. 0 is a hard cut; about 0.1 is a soft painted edge. It also softens cast shadows falling on characters.
- For shadows in the room, select the `Sun` and change **Shadow > Blur** (default 0.6): higher is softer. Its **Angular Distance** gives physically soft shadows that grow softer with distance, but costs more.

### Shadow colour

- **Shadow Color** (in **Colour**): what colour the shadow side is lit with, as a share of the light. Warm and a little purple keeps shadows rich; grey gives the flat "just darker" look we're avoiding.

### Base colours

- **Base Tint** (in **Colour**): multiplies every stylised character's own colours. Use it to warm or cool the whole cast together.
- **Ambient Strength** (in **Colour**, 0 to 1): how much of the room's ambient light reaches the characters. Lower leans on the sun and lamps for stronger shapes.
- A single character's colours come from its own texture; to shift one character, use the `tint` on its `ThirdPartyModel`.

### Outline thickness

In `character.tres`, group **Outline**:

- **Outline** (on/off).
- **Outline Thickness** (pixels at 1080p, default 1.6): the line stays this wide on screen near and far.
- **Outline Max Width** (metres, default 0.008): the widest it can be however close the camera, so small details (fingers, beak, buttons) don't get heavy lines in close-ups.
- **Outline Color**: dark brown by default, not black, so it reads as a painted line.

### Rim lighting

In `character.tres`, group **Rim**:

- **Rim Strength** (0 turns it off; default 0.2).
- **Rim Width** (0 to 1): how far in from the silhouette it reaches.
- **Rim Color**: warm cream by default. It only appears on the side the light reaches.

### Light intensity

- **The sun:** select `Sun`, then **Light > Energy** (golden default 3.0) and **Color**. While the scene runs, the cabin sets these from its own **Golden Sun Energy / Color** (on the `LookDevCabin` root, group **Sun**), so change those too.
- **The light shafts:** the sun's **Volumetric Fog > Energy** (default 10) makes the beams brighter; the fog itself is in `golden_cabin.tres` under **Volumetric Fog** (Density 0.006: more makes the room hazier, less leaves only the beams).
- **The lanterns:** each `Lamp`'s **Energy** (1.4 to 1.6) and **Range**; the glass's glow is the `Glow` node's **Energy** and **Threshold**.
- **Overall brightness:** `golden_cabin.tres` → **Tonemap > Exposure** (1.25), and **Ambient Light > Energy** (0.7).

### Bloom intensity

In `golden_cabin.tres`, group **Glow**:

- **Intensity** (default 0.3): how strong the bloom is.
- **HDR Threshold** (default 1.6): how bright something must be before it blooms. Raise it so only lanterns and the window glow; lower it and sunlit coats start to glow too.
- **Bloom** (default 0.02): a haze over everything; keep it near 0 for a crisp picture.

## The painted dusk (home waters, the opening)

Home waters has its own sky, grade and sea; the rest of the game is untouched. Try it with F6 on `scenes/prototype/intro/home_waters.tscn`.

| Part | File | Dials |
|---|---|---|
| The sky: gradient, sun, 3D painted clouds | `shaders/painted_sky.gdshader`, set in `data/art/skies/home_dusk_sky.tres` | Groups in the Inspector: *Sun* (disc, warm glow), *Sky Colors* (orange horizon on the sun's side, rose away), *Cumulus* (heights, cover, patchiness, density, size, wind), *Cumulus Light* (steps, Beer's law absorption, powder, silver lining, ambient, light gain), *Cloud Paint* (band count and softness, the four light colours, edge crispness), *Streaks* (high stratus), *Painted Finish* (ragged edges, canvas weave). |
| The grade, fog, glow | `data/art/environments/home_dusk.tres` | Ambient (a cool blue-violet; the warm light comes only from the `Sun`), Tonemap (AgX), Adjustments (saturation 1.2, contrast 1.12 and the colour ramp), Fog (thin indigo, density 0.001, so the buoy stays readable), Glow (threshold 1.8). |
| The sea | `assets/placeholder/materials/water_dusk.tres` (the shared shader is `shaders/water.gdshader`) | `deep_color` (navy), `paint_waves` (+ length, speed: short peaked wave strokes), `reflection_bands` and `reflection_floor` (painted steps on the wave faces, and how much sky near faces still catch), `glitter` and `sun_path` (+ width, colour: the orange column of sun), `sky_clouds` (stand-in clouds in the reflection), `sky_specular` (Godot's own reflection, 0 here: the shader paints it), `far_blend`, `foam_crisp`, and the sky colours/sun direction it mirrors. |
| Painted picture | the `PaintedLook` node, `keep_scene_grade` on | `haze_color` (dusky violet), `haze_strength` (0.1: more washed the picture out). With `keep_scene_grade` it leaves tone mapping, saturation and glow to the Environment, so the scene is graded once. |
| Lamp halos | `Halo` on the hanging lantern in `scenes/props/home/lamp_post.tscn` (it swings with it), material `assets/placeholder/materials/lamp_halo.tres` | The material's colour alpha (strength) and the quad's size. |

The sun's direction is read from the `Sun` node by the sky, but the water can't read it: if you turn the `Sun`, change *Sky Sun Direction* in `water_dusk.tres` to match. The night materials (`water.tres`) leave every dusk dial at 0, so the Grave and the ship's sea look as before.

The look (#247, third pass) is matched to a repaint of our own frame: a cool, dark world with warm focal points. Deep navy and indigo sea with violet-lit wave strokes; a vivid orange-gold sun path straight down the water; a purple sky with big soft cumulus, coral and orange on the sun side and violet underneath; a glowing orange horizon band; lanterns that really glow. Warm colour is saved for the sun, its path, the horizon, sunlit clouds and lamps.

The clouds are raymarched (see *Raymarching* and *Beer's law* in `docs/godot-notes.md`), then painted: the light is cut into four soft bands and the outline is cut sharp and roughened with brush noise. If they look too busy, lower *Cloud Cover* or raise *Band Softness*; for fatter lit sides, raise *Light Gain* or lower *Light Absorption*.

Cost (measured with the viewport's GPU timer on an RTX 4090 at 1920x1080, `march_steps` 18, `light_steps` 3): about 1.70 ms a frame with the cumulus, 1.65 ms without, so about 0.06 ms for the clouds. A mid-range card is perhaps eight times slower, about 0.5 ms. They are drawn at half resolution, rays below the horizon or past `cloud_far` stop at once, a ray stops once the cloud is solid, and the ambient cube map (Incremental, 128 px) uses half the steps and one sun step. Lower `march_steps` first if a machine struggles.

## What's not stylised

Only characters get the cel shader and outline. Rooms and props keep their own materials (and so their texture detail), and are drawn into the same palette by the light: the warm sun, the ambient colour, and the tone mapping.

## The home island's land (Terrain3D)

The island is a `Terrain3D` node (`scenes/props/home/home_island.tscn`), seen only from the water, so it is built to read from a rowboat: grassy shoulders on tiered rock cliffs, a winding flagstone path, a shingle cove and beach, wet dark rock and boulders at the waterline.

- **The shape** is `scripts/terrain/home_island_shape.gd`: a cone cut into tiers, then flat shelves for each building, the path's cut, the beach, the cove and the rocks. Every building and lamp keeps its old position, and the shelves and path are pinned to their heights. Change a number, then run `godot_console.exe --headless --path . --script tools/terrain/build_home_island.gd` (add `-- --preview=some.png` for a top-down picture) to sculpt it again. Hand sculpting in the editor is lost when it is run again.
- **The textures** are in `assets/placeholder/textures/terrain/`, in the terrain's order: 0 grass, 1 purple-grey rock, 2 wet rock, 3 shingle, 4 flagstones (the path). The first four are painted by `tools/terrain/paint_terrain_textures.gd` from seamless noise (run it, then import). The flagstones and the drystone wall are painted pictures made for the island (originals in `tools/terrain/originals/`, shrunk to 512; their bumps are read from their own brightness so they line up with the stones). To change one texture's look, edit its colours in the painter; to change how big its repeats are, change `tile` in `build_home_island.gd` (metres per repeat).
- **Which texture goes where** is worked out by the build tool: grass on gentle ground, rock where it is steepest, wet rock below about 2 m above the sea, shingle in the cove and on the beach, flagstones on the path. Patches of warm and cool tint and purple heather are in the colour map, and rock gets moss on its upward-facing parts.
- **Dressing** (`Dressing` node, `scripts/terrain/island_dressing.gd`): greybox trees, heather and drystone walls, set on the ground when the scene starts, for the Meshy kit to replace.

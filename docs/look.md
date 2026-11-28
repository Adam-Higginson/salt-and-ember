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
| The sea | `assets/placeholder/materials/water_dusk.tres` (shader `shaders/water_clear.gdshader`; the body shared with the night sea is `shaders/water.gdshaderinc`) | `deep_color` (navy), `paint_waves` (+ length, speed: short peaked wave strokes), `reflection_bands` and `reflection_floor` (painted steps on the wave faces, and how much sky near faces still catch), `glitter` and `sun_path` (+ width, colour: the orange column of sun), `sky_clouds` (stand-in clouds in the reflection), `sky_specular` (Godot's own reflection, 0 here: the shader paints it), `far_blend`, `foam_crisp`, and the sky colours/sun direction it mirrors. |
| Painted picture | the `PaintedLook` node, `keep_scene_grade` on | `haze_color` (dusky violet), `haze_strength` (0.1: more washed the picture out). With `keep_scene_grade` it leaves tone mapping, saturation and glow to the Environment, so the scene is graded once. |
| Lamp halos | `Halo` on the hanging lantern in `scenes/props/home/lamp_post.tscn` (it swings with it), material `assets/placeholder/materials/lamp_halo.tres` | The material's colour alpha (strength) and the quad's size. |

The sun's direction is read from the `Sun` node by the sky, but the water can't read it: if you turn the `Sun`, change *Sky Sun Direction* in `water_dusk.tres` (and *Sun Direction* on the spray's dab material in `sea_spray.tscn`) to match. The night materials (`water.tres`) leave every dusk dial at 0, so the Grave and the ship's sea look as before.

The look (#247, third pass) is matched to a repaint of our own frame: a cool, dark world with warm focal points. Deep navy and indigo sea with violet-lit wave strokes; a vivid orange-gold sun path straight down the water; a purple sky with big soft cumulus, coral and orange on the sun side and violet underneath; a glowing orange horizon band; lanterns that really glow. Warm colour is saved for the sun, its path, the horizon, sunlit clouds and lamps.

The clouds are raymarched (see *Raymarching* and *Beer's law* in `docs/godot-notes.md`), then painted: the light is cut into four soft bands and the outline is cut sharp and roughened with brush noise. If they look too busy, lower *Cloud Cover* or raise *Band Softness*; for fatter lit sides, raise *Light Gain* or lower *Light Absorption*.

Cost (measured with the viewport's GPU timer on an RTX 4090 at 1920x1080, `march_steps` 18, `light_steps` 3): about 1.70 ms a frame with the cumulus, 1.65 ms without, so about 0.06 ms for the clouds. A mid-range card is perhaps eight times slower, about 0.5 ms. They are drawn at half resolution, rays below the horizon or past `cloud_far` stop at once, a ray stops once the cloud is solid, and the ambient cube map (Incremental, 128 px) uses half the steps and one sun step. Lower `march_steps` first if a machine struggles.

### Waves, spray, see-through water and fish

The dusk sea has peaked waves with painted foam caps, spray off the crests and round the jetty piles, water you can see a little way into, and a few shoals of fish under the boat. The night seas (the Grave, the ship's sea) are untouched: their swell has no peaks, and they keep the opaque water shader.

| Part | File | Dials |
|---|---|---|
| The waves | `data/sea/dusk_swell.tres` (four `WaveLayer`s) | Each layer's **Peak** (0 to 1; 0 is the old gentle shape): how pointed its crests are. Ours: the 60 m swell 0.12, the 16 m waves you see 0.4, a 10.5 m cross sea 0.22, a 6 m chop 0.1. Keep the peaks added up under 1, or crests fold where they meet. The rowboat rides these same numbers. |
| Foam caps | `water_dusk.tres` | `crest_paint` (0.8; 0 is off), `crest_foam_from` (0.55: how pointed a crest must be; lower foams more), `crest_softness` (0.12: the cap's edge), `crest_sun` (0.6: how much the caps catch the sun's colour). |
| Wave backs | `water_dusk.tres` | `self_shade` (0.85): a steep wave's back mirrors the dark sea in front of it rather than the bright sky. `fresnel_power` is 5.5 here, so the near water stays navy. |
| See-through | `water_dusk.tres`, shader `shaders/water_clear.gdshader` | `clarity` (0.85: how see-through looking down; 0 is opaque-looking), `clear_depth` (1.6 m) and `clear_tint`: after that many metres of water, light is tinted by that colour (Beer-Lambert), so things fade to navy with depth. `refraction` (0.02) bends them with the waves. |
| Spray | `scenes/prototype/weather/sea_spray.tscn` (`SeaSpray`, shader `shaders/sea_spray.gdshader`, dabs `shaders/spray_drop.gdshader`) | On the process material: `crest_from` (0.3: how pointed a crest must be to throw spray), `bursts`, `lift`, `blow`, `sizes`, `post_from` (how high the water must rise round a pile). On the node: `radius` round the boat and `posts` (the jetty piles, world x and z, set in `home_waters.tscn`). On the dab material: `cool_color`, `warm_color` (towards the sun) and `strength`. |
| Fish | `scenes/prototype/weather/sea_shoal.tscn` (`SeaShoal`, shader `shaders/fish.gdshader`) | `shoals` (3) of `fish_per_shoal` (8), `anchors` (the rowboat twice and the jetty, in `home_waters.tscn`), `roam`, `speed`, `depth` (1 m), `fish_length`, `scatter_within` (how close the oars must dip to send them darting). The material's `glow` (0.35) keeps them readable through the dark water. |

The see-through water reads the screen, so Godot draws it after everything solid. Two consequences: PaintedLook's brush filter (drawn first of the see-through things) no longer paints the water, which is painted by its own shader; and things under the water are the solid picture dimmed and tinted, so the water writes its own depth for the spray and halos to sort against it. The sea plane in home waters is finer than elsewhere (a 1.2 m grid, 400 by 400) so the shorter waves keep their peaks.

Cost (GPU timer, RTX 4090, 1920x1080, the camera behind the boat): about 1.44 to 1.54 ms a frame with all of it, 1.46 ms with the old opaque sea, coarse grid and no spray or fish, so the difference is within the timer's noise, under about 0.1 ms.

## What's not stylised

Only characters get the cel shader and outline. Rooms and props keep their own materials (and so their texture detail), and are drawn into the same palette by the light: the warm sun, the ambient colour, and the tone mapping.

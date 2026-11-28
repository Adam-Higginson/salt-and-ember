// The sea you can see a little way into (home waters' dusk): the same sea as
// water.gdshader (the body is in water.gdshaderinc), plus whatever is under
// the surface showing through, dimmed and tinted with depth. See CLEAR_WATER
// in the include, and its dials (clarity, clear_depth, clear_tint).
//
// Reading the screen makes it see-through, so Godot draws it after
// everything solid: it isn't painted by PaintedLook's filter (drawn first of
// the see-through things), and it writes its own depth so the spray and the
// lamp halos sort in front of and behind it properly.
shader_type spatial;
render_mode cull_back, depth_draw_always;

#define CLEAR_WATER
#include "res://shaders/water.gdshaderinc"

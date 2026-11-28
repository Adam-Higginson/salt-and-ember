// The sea. Gerstner waves (the same maths as scripts/sea/waves.gd) move the
// surface; detail ripples, rain rings and foam (on crests, along the hull and
// in the wake) are added per pixel. Sea (scripts/sea/sea.gd) sets the
// uniforms every frame. Godot's fog is applied on top, which hides the edge.
//
// This one is opaque: the night seas (the Grave, the ship's sea) use it. The
// body is in water.gdshaderinc, shared with water_clear.gdshader (the dusk sea
// you can see a little way into).
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

#include "res://shaders/water.gdshaderinc"

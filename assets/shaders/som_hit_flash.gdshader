shader_type canvas_item;
// gl_compatibility: korte witte flits voor vijanden zonder hurt-sheet (bazen).
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash * c.a), c.a);
}
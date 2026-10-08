shader_type canvas_item;
// Korte glitch (0,1 sec, af en toe): kleuren schuiven uit elkaar (chromatische aberratie) en
// een smalle band verspringt opzij. Staat alleen aan tijdens zo'n glitch (crt_overlay.gd).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float aberration = 1.5;     // pixels
uniform float band_y = 0.5;         // midden van de verspringende band (0..1)
uniform float band_h = 0.03;
uniform float band_shift = 6.0;     // pixels

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	if (abs(uv.y - band_y) < band_h) {
		uv.x += band_shift * px.x;
	}
	float r = texture(screen_tex, uv + vec2(aberration * px.x, 0.0)).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - vec2(aberration * px.x, 0.0)).b;
	COLOR = vec4(r, g, b, 1.0);
}

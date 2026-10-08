shader_type canvas_item;
// Scanlines + vignet (v7 'De Vergeten Bibliotheek'). Alleen donker maken, dus goedkoop:
// het scherm wordt niet uitgelezen. De sterkte komt uit game_data.gd (CRT), via crt_overlay.gd.

uniform float intensity : hint_range(0.0, 1.0) = 0.2;   // donkerte van de lijnen
uniform float period = 2.0;                             // om de hoeveel beeldpixels een lijn
uniform float vignette : hint_range(0.0, 1.0) = 0.28;   // donkere hoeken
uniform float flash = 0.0;                              // heel even lichter (glitch)

void fragment() {
	float row = mod(floor(FRAGCOORD.y), period);
	float line_dark = row >= period * 0.5 ? intensity : 0.0;
	vec2 c = SCREEN_UV - vec2(0.5);
	c.x *= 1.2;
	float v = smoothstep(0.30, 0.86, length(c)) * vignette;
	float a = 1.0 - (1.0 - line_dark) * (1.0 - v);
	COLOR = vec4(vec3(flash), max(a - flash * 0.5, 0.0));
}

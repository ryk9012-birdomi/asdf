class_name SpaceBackdrop
extends ColorRect
## Animated nebula and starfield drawn by a shader; purely decorative.

const SHADER_CODE := """
shader_type canvas_item;

uniform vec4 deep_color : source_color = vec4(0.015, 0.027, 0.06, 1.0);
uniform vec4 nebula_a : source_color = vec4(0.12, 0.62, 0.66, 1.0);
uniform vec4 nebula_b : source_color = vec4(0.62, 0.20, 0.50, 1.0);
uniform vec2 resolution = vec2(1280.0, 920.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 5; octave++) {
		value += amplitude * noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

float stars(vec2 uv, float scale, float t) {
	vec2 grid = uv * scale;
	vec2 id = floor(grid);
	vec2 cell = fract(grid) - 0.5;
	float seed = hash(id);
	if (seed < 0.92) {
		return 0.0;
	}
	vec2 offset = vec2(hash(id + 1.7), hash(id + 3.1)) - 0.5;
	float dist = length(cell - offset * 0.6);
	float twinkle = 0.55 + 0.45 * sin(t * (1.0 + seed * 3.0) + seed * 40.0);
	return smoothstep(0.09, 0.0, dist) * twinkle;
}

void fragment() {
	vec2 uv = UV * vec2(resolution.x / max(resolution.y, 1.0), 1.0);
	float t = TIME;
	vec2 drift = vec2(t * 0.006, t * 0.002);
	float n = fbm(uv * 1.6 + drift);
	float m = fbm(uv * 3.1 - drift * 1.7 + n);
	vec3 col = deep_color.rgb;
	col = mix(col, nebula_a.rgb * 0.34, smoothstep(0.45, 0.85, n) * 0.9);
	col = mix(col, nebula_b.rgb * 0.30, smoothstep(0.50, 0.90, m) * 0.75);
	col += vec3(0.85, 0.92, 1.0) * (stars(uv, 58.0, t) * 0.95 + stars(uv + 3.7, 118.0, t * 1.3) * 0.55);
	col *= 0.965 + 0.035 * sin(FRAGCOORD.y * 1.6);
	col *= 1.0 - smoothstep(0.42, 0.95, distance(UV, vec2(0.5))) * 0.7;
	COLOR = vec4(col, 1.0);
}
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color("04070f")
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	material = shader_material
	resized.connect(update_resolution)
	update_resolution()


func update_resolution() -> void:
	(material as ShaderMaterial).set_shader_parameter("resolution", size)

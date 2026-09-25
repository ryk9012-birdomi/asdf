class_name EmberBackdrop
extends ColorRect
## Torch-lit cavern haze with rising embers, drawn by a shader; purely decorative.

const SHADER_CODE := """
shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.035, 0.024, 0.018, 1.0);
uniform vec4 smoke_color : source_color = vec4(0.30, 0.17, 0.10, 1.0);
uniform vec4 torch_color : source_color = vec4(1.0, 0.55, 0.20, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.62, 0.25, 1.0);
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

float embers(vec2 uv, float scale, float speed, float t) {
	vec2 grid = uv * scale;
	grid.y += t * speed;
	vec2 id = floor(grid);
	vec2 cell = fract(grid) - 0.5;
	float seed = hash(id);
	if (seed < 0.86) {
		return 0.0;
	}
	vec2 offset = vec2(hash(id + 1.7), hash(id + 3.1)) - 0.5;
	offset.x += sin(t * (0.8 + seed) + seed * 30.0) * 0.25;
	float dist = length(cell - offset * 0.7);
	float flicker = 0.45 + 0.55 * sin(t * (2.0 + seed * 5.0) + seed * 40.0);
	return smoothstep(0.10, 0.0, dist) * flicker;
}

void fragment() {
	float aspect = resolution.x / max(resolution.y, 1.0);
	vec2 uv = UV * vec2(aspect, 1.0);
	float t = TIME;
	float smoke = fbm(uv * 1.8 + vec2(t * 0.012, -t * 0.03));
	float wisps = fbm(uv * 3.4 + vec2(-t * 0.02, -t * 0.05) + smoke);
	vec3 col = shadow_color.rgb;
	col = mix(col, smoke_color.rgb * 0.55, smoothstep(0.40, 0.90, smoke) * 0.85);
	col += smoke_color.rgb * 0.18 * smoothstep(0.55, 0.95, wisps);
	float flicker = 0.85 + 0.15 * sin(t * 7.0) * sin(t * 3.1 + 1.3);
	float left_torch = exp(-distance(UV, vec2(0.0, 0.92)) * 3.2);
	float right_torch = exp(-distance(UV, vec2(1.0, 0.92)) * 3.2);
	col += torch_color.rgb * (left_torch + right_torch) * 0.42 * flicker;
	col += torch_color.rgb * 0.06 * smoothstep(0.35, 1.0, UV.y);
	float glow = embers(uv, 26.0, 1.3, t) * 0.9 + embers(uv + 5.3, 52.0, 2.1, t) * 0.55;
	col += ember_color.rgb * glow * (0.35 + 0.65 * UV.y);
	col *= 1.0 - smoothstep(0.38, 0.92, distance(UV, vec2(0.5, 0.45))) * 0.78;
	COLOR = vec4(col, 1.0);
}
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color("0a0705")
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	material = shader_material
	resized.connect(update_resolution)
	update_resolution()


func update_resolution() -> void:
	(material as ShaderMaterial).set_shader_parameter("resolution", size)

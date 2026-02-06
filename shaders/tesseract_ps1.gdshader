shader_type spatial;
render_mode unshaded;

uniform float time;
uniform float wobble_intensity : hint_range(0, 1) = 0.8;

vec3 ps1_wobble(vec3 pos) {
	float t = time * 12.0;
	float seed = sin(pos.x * 13.0 + pos.y * 17.0 + pos.z * 23.0 + t) * 12345.0;
	float jitter = (fract(seed) - 0.5) * wobble_intensity * 0.04;
	return pos + vec3(jitter, jitter * 0.7, jitter * 1.3);
}
vec3 ps1_quantize(vec3 color) {
	float r = round(color.r * 31.0) / 31.0;
	float g = round(color.g * 63.0) / 63.0;
	float b = round(color.b * 31.0) / 31.0;
	return vec3(r, g, b);
}
void vertex() {
	float angle = time * 0.6;
	mat3 rot_y = mat3(
		vec3(cos(angle), 0.0, -sin(angle)),
		vec3(0.0, 1.0, 0.0),
		vec3(sin(angle), 0.0, cos(angle))
	);
	mat3 rot_x = mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, cos(angle * 0.7), -sin(angle * 0.7)),
		vec3(0.0, sin(angle * 0.7), cos(angle * 0.7))
	);
	vec3 rotated = rot_y * rot_x * VERTEX;
	VERTEX = ps1_wobble(rotated);
}
void fragment() {
	ALBEDO = ps1_quantize(COLOR.rgb);
}
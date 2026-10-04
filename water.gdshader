shader_type spatial;
render_mode cull_back;

uniform vec3 albedo : source_color = vec3(0.0, 0.32, 0.43);
uniform vec3 albedo2 : source_color = vec3(0.0, 0.47, 0.76);
uniform float metallic : hint_range(0.0, 1.0) = 0.6;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float wave_direction = 1.0;
uniform float wave_speed = 0.15;
uniform float wave_scale = 0.2;

uniform sampler2D texture_normal : hint_normal;
uniform sampler2D texture_normal2 : hint_normal;

void fragment() {
	vec2 time = (TIME * wave_direction) * vec2(wave_speed, wave_speed);
	vec3 normal_blend = mix(texture(texture_normal, UV + time).rgb, texture(texture_normal2, UV - time).rgb, 0.5);
	
	ALBEDO = mix(albedo, albedo2, 0.5);
	METALLIC = metallic;
	ROUGHNESS = roughness;
	NORMAL_MAP = normal_blend;
    ALPHA = 0.85;
}

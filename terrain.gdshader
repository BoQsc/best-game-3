shader_type spatial;
render_mode world_vertex_coords;

// Textures
uniform sampler2D grass_texture : source_color, filter_linear_mipmap;
uniform sampler2D road_texture : source_color, filter_linear_mipmap;
uniform sampler2D sand_texture : source_color, filter_linear_mipmap;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap;
uniform sampler2D snow_texture : source_color, filter_linear_mipmap;

uniform float texture_scale = 0.1;

// Varyings
varying float road_weight;
varying vec3 w_normal;
varying vec3 w_vertex; // World Vertex interpolated
varying float height;

void vertex() {
    road_weight = COLOR.r;
    
    // Pass World Normal to fragment for pixel-perfect triplanar blending
    // With world_vertex_coords, NORMAL is World Space.
    w_normal = NORMAL;
    
    // Pass World Position
    w_vertex = VERTEX;
    
    // Height for biomes
    height = VERTEX.y;
}

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
    vec4 samp = texture(p_sampler, p_triplanar_pos.xy) * p_weights.z; // Top/Bottom
    // Only sample the side projections when they actually contribute: for flat
    // ground the X/Y weights are ~0, so this skips two texture fetches.
    if (p_weights.x + p_weights.y > 0.001) {
        samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y; // Front/Back
        samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x; // Left/Right
    }
    return samp;
}

void fragment() {
    // 1. Calculate Triplanar Weights in Fragment Shader (Stable)
    vec3 normal = normalize(w_normal);
    vec3 power_normal = pow(abs(normal), vec3(4.0));
    power_normal /= dot(power_normal, vec3(1.0));
    
    // 2. Calculate Texture Coordinates
    vec3 triplanar_pos = w_vertex * texture_scale;

    // Sample only what this pixel needs: grass always, the rest only when
    // their blend weight is non-zero (big saving on low-end / mobile GPUs).
    vec3 grass = triplanar_texture(grass_texture, power_normal, triplanar_pos).rgb;
    vec3 final_albedo = grass;

    // 1. Height Mixing (Sand vs Grass vs Snow)
    // Water is usually around 15.0. Beach up to 18.0.
    float sand_factor = 1.0 - smoothstep(15.0, 19.0, height);
    if (sand_factor > 0.001) {
        vec3 sand = triplanar_texture(sand_texture, power_normal, triplanar_pos).rgb;
        final_albedo = mix(final_albedo, sand, sand_factor);
    }

    // Snow starts at 50, fully snow by 70
    float snow_factor = smoothstep(50.0, 70.0, height);
    if (snow_factor > 0.001) {
        vec3 snow = triplanar_texture(snow_texture, power_normal, triplanar_pos).rgb;
        final_albedo = mix(final_albedo, snow, snow_factor);
    }

    // 2. Slope Mixing (Rock)
    // Use the pixel normal for slope check
    float slope = normal.y;
    float rock_factor = 1.0 - smoothstep(0.5, 0.8, slope);
    if (rock_factor > 0.001) {
        vec3 rock = triplanar_texture(rock_texture, power_normal, triplanar_pos).rgb;
        final_albedo = mix(final_albedo, rock, rock_factor);
    }

    // 3. Road Overlay (Man-made overrides everything)
    if (road_weight > 0.001) {
        vec3 road = triplanar_texture(road_texture, power_normal, triplanar_pos).rgb;
        final_albedo = mix(final_albedo, road, road_weight);
    }

    ALBEDO = final_albedo;
    ROUGHNESS = 0.9;
    
    // Simple specular adjustment
    if (sand_factor > 0.5 && road_weight < 0.1) {
        ROUGHNESS = 0.6; // Wet sand look
    }
}

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 helmet_color : source_color = vec4(1.0);
uniform bool custom_color = false;
void fragment() {
    vec3 c = texture(paint, UV).rgb;
    float hi = max(c.r, max(c.g, c.b));
    float lo = min(c.r, min(c.g, c.b));
    // Keep the dark visor and neutral sponsor marks when the career colour changes.
    float visor_band = smoothstep(0.325, 0.345, UV.y) * (1.0 - smoothstep(0.575, 0.595, UV.y));
    float front = smoothstep(0.19, 0.24, UV.x) * (1.0 - smoothstep(0.76, 0.81, UV.x));
    float tint = smoothstep(0.025, 0.16, hi - lo) * smoothstep(0.035, 0.13, hi);
    ALBEDO = custom_color ? mix(c, helmet_color.rgb * (0.65 + 0.35 * hi), tint) : c;
    vec3 shell = custom_color ? helmet_color.rgb : texture(paint, vec2(0.08, 0.12)).rgb;
    ALBEDO = mix(ALBEDO, shell, visor_band * (1.0 - front));
    visor_band *= front;
    ALBEDO = mix(ALBEDO, vec3(0.012, 0.020, 0.032), visor_band);
    float visor = visor_band;
    METALLIC = mix(0.12, 0.3, visor);
    ROUGHNESS = mix(0.31, 0.18, visor);
    CLEARCOAT = 0.45;
    CLEARCOAT_ROUGHNESS = 0.25;
}

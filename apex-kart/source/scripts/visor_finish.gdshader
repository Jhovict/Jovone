shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform vec4 tint : source_color = vec4(0.02, 0.045, 0.08, 1.0);
void fragment() {
    float edge = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
    ALBEDO = mix(tint.rgb * mix(0.60, 1.15, UV.y), vec3(0.12, 0.23, 0.33), edge * 0.35);
    METALLIC = 0.68;
    ROUGHNESS = 0.16;
    CLEARCOAT = 0.85;
    CLEARCOAT_ROUGHNESS = 0.12;
}

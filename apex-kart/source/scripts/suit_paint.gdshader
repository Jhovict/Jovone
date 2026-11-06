shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic;
uniform bool custom_style = false;
uniform vec4 style_color : source_color = vec4(1.0);
varying float back_face;
void vertex() {
    back_face = step(0.215, VERTEX.z);
}
void fragment() {
    vec2 uv = UV;
    // The source mesh uses a front projection. Mirror only the back sampling,
    // so the sponsor reads correctly from the chase camera as well.
    uv.x = mix(uv.x, 1.0 - uv.x, step(0.5, back_face));
    vec3 tex = texture(paint, uv).rgb;
    float bright = max(tex.r, max(tex.g, tex.b));
    float markings = smoothstep(0.78, 0.95, min(tex.r, min(tex.g, tex.b)));
    ALBEDO = custom_style ? mix(style_color.rgb * (0.55 + bright * 0.45), tex, markings) : tex;
    ROUGHNESS = 0.82;
    METALLIC = 0.0;
}

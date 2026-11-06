shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform int finish = 0;
uniform vec3 wheel_up = vec3(0.0, 1.0, 0.0);
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
    vec2 uv = UV;
    if (finish == 0) {
        vec2 grain_uv = uv * vec2(420.0, 65.0);
        float grain = hash(floor(grain_uv));
        float detail = 1.0 - smoothstep(0.4, 1.5, max(fwidth(grain_uv.x), fwidth(grain_uv.y)));
        vec2 holes = fract(uv * vec2(110.0, 14.0)) - 0.5;
        float perforation = 1.0 - smoothstep(0.10, 0.22, length(holes));
        ALBEDO = vec3(0.022, 0.025, 0.030) * (1.0 + (grain - 0.5) * 0.28 * detail);
        ALBEDO *= 1.0 - perforation * detail * 0.45;
        ROUGHNESS = 0.78 + (grain - 0.5) * 0.12 * detail;
        METALLIC = 0.0;
        float band = (1.0 - smoothstep(0.004, 0.005, abs(local_position.x))) * smoothstep(0.061, 0.064, dot(local_position, wheel_up));
        ALBEDO = mix(ALBEDO, vec3(0.92, 0.60, 0.035), band);
        ROUGHNESS = mix(ROUGHNESS, 0.62, band);
    } else {
        vec2 weave_uv = uv * 64.0;
        vec2 tile = floor(weave_uv);
        float crossing = mod(tile.x + tile.y, 2.0);
        float thread = mix(fract(weave_uv.x), fract(weave_uv.y), crossing);
        float weave = 0.5 + 0.5 * sin(thread * 3.14159265);
        float detail = 1.0 - smoothstep(0.4, 1.5, max(fwidth(weave_uv.x), fwidth(weave_uv.y)));
        ALBEDO = vec3(0.032, 0.037, 0.045) * mix(1.0, 0.75 + weave * 0.65, detail);
        METALLIC = 0.35;
        ROUGHNESS = 0.38;
        CLEARCOAT = 0.25;
        CLEARCOAT_ROUGHNESS = 0.3;
    }
}

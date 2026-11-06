shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform bool tyre = false;
uniform float dirt = 0.0;
uniform float damage = 0.0;
varying vec3 local_pos;
void vertex(){ local_pos=VERTEX; VERTEX+=NORMAL*0.0005; }
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
void fragment(){
 float speck=hash(floor(local_pos*190.0));
 float grime=smoothstep(.6,.95,speck)*dirt*.32;
 float scratch=pow(abs(sin(local_pos.x*680.0+local_pos.y*120.0)),36.0)*step(.73,hash(floor(local_pos*55.0)))*damage*.3;
 ALBEDO=tyre ? mix(vec3(.025),vec3(.11,.09,.07),dirt) : mix(vec3(.16,.11,.06),vec3(.56,.58,.59),scratch);
 ALPHA=clamp(grime+scratch*.8,0.0,.8);
 ROUGHNESS=.94;
}

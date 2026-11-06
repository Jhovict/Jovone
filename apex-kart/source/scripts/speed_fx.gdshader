// Sensação de velocidade por cima da imagem: riscos de vento saindo do centro (só nas bordas, o meio da
// tela fica limpo) e um escurecimento leve dos cantos. Não lê a tela, então custa pouco no celular.
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float flow = 0.0;              // avanço acumulado (cresce com a velocidade)
uniform vec2 center = vec2(0.5, 0.42); // ponto de fuga (um pouco acima do meio, onde fica a pista)
uniform float aspect = 1.7778;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec2 d = UV - center;
	d.x *= aspect;
	float r = length(d);
	float a = atan(d.y, d.x) / 6.2831853 + 0.5;
	// riscos: cada fatia do ângulo tem um risco curto que corre para fora em velocidade própria
	float cells = 150.0;
	float id = floor(a * cells);
	float fa = fract(a * cells);
	float rnd = hash(id);
	float rnd2 = hash(id + 31.7);
	float width = (1.0 - smoothstep(0.15, 0.5, abs(fa - 0.5))) ;
	float run = fract(r * 0.9 - flow * (0.6 + rnd2 * 0.8) + rnd);
	float streak = smoothstep(0.0, 0.08, run) * (1.0 - smoothstep(0.12, 0.55, run));
	float on = step(0.55, rnd);                          // só parte das fatias tem risco
	float edge = smoothstep(0.42, 0.95, r);
	float lines = streak * width * on * edge * intensity * 0.075;
	float vig = smoothstep(0.55, 1.25, r) * intensity * 0.12;
	float alpha = lines + vig * (1.0 - lines);
	vec3 rgb = vec3(1.0) * lines;
	COLOR = vec4(rgb / max(alpha, 0.0001), alpha);
}

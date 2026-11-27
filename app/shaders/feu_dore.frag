#version 460 core
// Carte détruite par le feu doré, porté de scripts/ui/feu_dore.gdshader : le front de flamme
// monte du bas, irrégulier ; devant lui le parchemin roussit, se carbonise, puis une bordure
// de braises brille avant que le reste ne disparaisse.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;      // taille de la carte (pixels logiques)
uniform float uProgress; // 0 : intacte ; 1 : consumée
uniform float uSeed;
uniform sampler2D uImage; // photo de la carte

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21) + uSeed);
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * vnoise(p);
    p *= 2.03;
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 c = texture(uImage, uv);
  if (c.a < 0.004) {
    fragColor = vec4(0.0);
    return;
  }
  vec2 nuv = uv * vec2(1.0, uSize.y / uSize.x) * 2.6;
  float n = fbm(nuv) * 0.7 + fbm(nuv * 3.1 + vec2(0.37, 0.11)) * 0.3;
  // Hauteur à laquelle ce point brûle : le bas d'abord, avec des langues irrégulières.
  float h = (1.0 - uv.y) * 0.78 + n * 0.34;
  float front = uProgress * 1.3 - 0.1;
  float d = h - front;
  if (d < 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  vec3 col = c.rgb / c.a;
  float scorch = 1.0 - smoothstep(0.03, 0.17, d);
  col = mix(col, col * vec3(0.62, 0.42, 0.24), scorch * 0.85);
  float charZone = 1.0 - smoothstep(0.016, 0.05, d);
  col = mix(col, vec3(0.13, 0.06, 0.03), charZone);
  float glow = 1.0 - smoothstep(0.0, 0.024, d);
  vec3 ember = mix(vec3(1.0, 0.96, 0.62), vec3(1.0, 0.48, 0.08), smoothstep(0.0, 0.024, d));
  col = mix(col, ember * 1.3, glow);
  fragColor = vec4(min(col, vec3(1.0)) * c.a, c.a);
}

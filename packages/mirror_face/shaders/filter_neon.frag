#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform float uTime;

out vec4 fragColor;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    vec2 px = 1.0 / uResolution;

    // Sobel at 1px
    float tl = lum(texture(uTexture, uv + vec2(-px.x,  px.y)).rgb);
    float tc = lum(texture(uTexture, uv + vec2( 0.0,   px.y)).rgb);
    float tr = lum(texture(uTexture, uv + vec2( px.x,  px.y)).rgb);
    float ml = lum(texture(uTexture, uv + vec2(-px.x,  0.0 )).rgb);
    float mr = lum(texture(uTexture, uv + vec2( px.x,  0.0 )).rgb);
    float bl = lum(texture(uTexture, uv + vec2(-px.x, -px.y)).rgb);
    float bc = lum(texture(uTexture, uv + vec2( 0.0,  -px.y)).rgb);
    float br = lum(texture(uTexture, uv + vec2( px.x, -px.y)).rgb);
    float gx = -tl - 2.0*ml - bl + tr + 2.0*mr + br;
    float gy = -tl - 2.0*tc - tr + bl + 2.0*bc + br;
    float edge = sqrt(gx*gx + gy*gy);
    float edgeAngle = atan(gy, gx);

    // Wide Sobel at 3px for bloom
    vec2 px3 = px * 3.0;
    float gx3 = lum(texture(uTexture, uv + vec2( px3.x,  px3.y)).rgb)
              + lum(texture(uTexture, uv + vec2( px3.x, -px3.y)).rgb)
              - lum(texture(uTexture, uv + vec2(-px3.x,  px3.y)).rgb)
              - lum(texture(uTexture, uv + vec2(-px3.x, -px3.y)).rgb);
    float gy3 = lum(texture(uTexture, uv + vec2(-px3.x,  px3.y)).rgb)
              + lum(texture(uTexture, uv + vec2( px3.x,  px3.y)).rgb)
              - lum(texture(uTexture, uv + vec2(-px3.x, -px3.y)).rgb)
              - lum(texture(uTexture, uv + vec2( px3.x, -px3.y)).rgb);
    float glow = sqrt(gx3*gx3 + gy3*gy3) * 0.35;

    // Neon color: hue from edge angle + slow time animation
    float hue = fract((edgeAngle / 6.28318) + uTime * 0.07);
    float h6 = hue * 6.0;
    float c = 1.0;
    float x = c * (1.0 - abs(mod(h6, 2.0) - 1.0));
    vec3 neon;
    if      (h6 < 1.0) neon = vec3(c, x, 0.0);
    else if (h6 < 2.0) neon = vec3(x, c, 0.0);
    else if (h6 < 3.0) neon = vec3(0.0, c, x);
    else if (h6 < 4.0) neon = vec3(0.0, x, c);
    else if (h6 < 5.0) neon = vec3(x, 0.0, c);
    else               neon = vec3(c, 0.0, x);

    float coreEdge = smoothstep(0.15, 0.55, edge);
    float glowEdge = smoothstep(0.04, 0.20, edge + glow);

    vec3 col = neon * glowEdge * 0.45 + neon * coreEdge;
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

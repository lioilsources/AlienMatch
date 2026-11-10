#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform float uTime;

out vec4 fragColor;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

float rand(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;

    // Rare glitch rows: red channel splits horizontally for one beat
    float row = floor(uv.y * 24.0);
    float g = rand(vec2(row, floor(uTime * 2.0)));
    float glitch = step(0.93, g);
    float shift = (g - 0.965) * 0.25 * glitch;

    vec3 col = texture(uTexture, uv).rgb;
    col.r = texture(uTexture, clamp(uv + vec2(shift, 0.0), 0.0, 1.0)).r;

    // Chrome grade
    float l = lum(col);
    vec3 steel = vec3(l) * vec3(0.85, 0.92, 1.05);
    steel = mix(vec3(0.5), steel, 1.35);
    col = mix(col, steel, 0.8);

    // Scanlines tied to device rows (no moire)
    col *= 0.84 + 0.16 * sin(uv.y * uResolution.y * 3.14159);

    // Procedural cyan HUD: corner brackets + pulsing grid
    vec3 hud = vec3(0.2, 0.9, 1.0);
    float pulse = 0.7 + 0.3 * sin(uTime * 2.5);
    vec2 b = min(uv, 1.0 - uv);
    float bracket = step(abs(b.x - 0.05), 0.0035) * step(b.y, 0.18)
                  + step(abs(b.y - 0.05), 0.0035) * step(b.x, 0.18);
    col = mix(col, hud, clamp(bracket, 0.0, 1.0) * pulse);
    vec2 cellPx = fract(uv * 8.0) * (uResolution / 8.0);
    float grid = step(cellPx.x, 1.5) + step(cellPx.y, 1.5);
    col = mix(col, hud, 0.25 * clamp(grid, 0.0, 1.0) * pulse);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform float uTime;

out vec4 fragColor;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;

    float row = floor(uv.y * uResolution.y / 4.0);
    float tearAmt  = (rand(vec2(row, floor(uTime * 8.0))) - 0.5) * 0.04;
    float tearMask = step(0.92, rand(vec2(row * 0.3, floor(uTime * 3.0))));
    float offsetX  = tearAmt * tearMask;

    vec2 uvR = vec2(uv.x + offsetX + 0.005, uv.y);
    vec2 uvG = vec2(uv.x + offsetX,         uv.y);
    vec2 uvB = vec2(uv.x + offsetX - 0.005, uv.y);

    float r = texture(uTexture, fract(uvR)).r;
    float g = texture(uTexture, fract(uvG)).g;
    float b = texture(uTexture, fract(uvB)).b;

    float blockY    = floor(uv.y * 18.0);
    float blockRand = rand(vec2(blockY, floor(uTime * 5.0)));
    if (blockRand > 0.96) {
        float shift = (rand(vec2(blockY * 1.3, uTime)) - 0.5) * 0.08;
        vec2 uvShifted = fract(vec2(uv.x + shift, uv.y));
        r = texture(uTexture, uvShifted).r;
        g = texture(uTexture, uvShifted).g;
        b = texture(uTexture, uvShifted).b;
    }

    float scanline = 0.85 + 0.15 * sin(uv.y * uResolution.y * 3.14159);
    float noise = (rand(uv + fract(uTime)) - 0.5) * 0.08;

    vec3 col = vec3(r, g, b) * scanline + noise;
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

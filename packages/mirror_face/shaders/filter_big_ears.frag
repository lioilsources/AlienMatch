#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform vec2 uFaceCenter;
uniform float uFaceScale;

out vec4 fragColor;

// One strong magnifying lens per ear at the sides of the head.
vec2 earLens(vec2 d, vec2 ear, float R) {
    vec2 k = d - ear;
    float sigma = 0.34 * R;
    float w = exp(-dot(k, k) / (sigma * sigma));
    return k * (1.0 - 0.45 * w) + ear - d;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float aspect = uResolution.x / uResolution.y;
    float R = uFaceScale;

    vec2 d = uv - uFaceCenter;
    d.x *= aspect;

    vec2 earL = vec2(-0.85 * R, -0.02 * R);
    vec2 earR = vec2(0.85 * R, -0.02 * R);

    vec2 src = d + earLens(d, earL, R) + earLens(d, earR, R);
    src.x /= aspect;
    vec2 wUV = clamp(uFaceCenter + src, 0.0, 1.0);

    fragColor = vec4(texture(uTexture, wUV).rgb, 1.0);
}

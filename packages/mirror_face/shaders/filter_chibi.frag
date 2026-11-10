#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform vec2 uFaceCenter;
uniform float uFaceScale;

out vec4 fragColor;

// Chibi: each eye gets its own gentle magnifying lens (unlike doll's single
// band), keeping the effect subtle — pretty, not grotesque.
vec2 eyeLens(vec2 d, vec2 eye, float R) {
    vec2 k = d - eye;
    float sigma = 0.26 * R;
    float w = exp(-dot(k, k) / (sigma * sigma));
    // Sampling closer to the eye center magnifies it.
    return k * (1.0 - 0.20 * w) + eye - d;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float aspect = uResolution.x / uResolution.y;
    float R = uFaceScale;

    vec2 d = uv - uFaceCenter;
    d.x *= aspect;

    vec2 eyeL = vec2(-0.32 * R, -0.30 * R);
    vec2 eyeR = vec2(0.32 * R, -0.30 * R);

    vec2 src = d + eyeLens(d, eyeL, R) + eyeLens(d, eyeR, R);
    src.x /= aspect;
    vec2 wUV = clamp(uFaceCenter + src, 0.0, 1.0);

    vec3 col = texture(uTexture, wUV).rgb;

    // A whisper of brightness so the look reads "cute", not just warped.
    col = pow(clamp(col, 0.0, 1.0), vec3(0.95));

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

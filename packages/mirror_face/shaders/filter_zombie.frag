#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform vec2 uFaceCenter;
uniform float uFaceScale;

out vec4 fragColor;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

float rand(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float aspect = uResolution.x / uResolution.y;

    vec3 col = texture(uTexture, uv).rgb;

    // Gray-green undead grade
    float l = lum(col);
    col = mix(vec3(l), col, 0.4) * vec3(0.62, 0.80, 0.58);

    // Face-centered mask keeps the decay on the face
    vec2 d = uv - uFaceCenter;
    d.x *= aspect;
    float face = exp(-dot(d, d) / (0.9 * uFaceScale * uFaceScale));

    // Two-octave value noise, soft-thresholded into rot blotches;
    // deliberately static (no uTime) so the decay does not crawl
    float n = 0.65 * vnoise(uv * 14.0) + 0.35 * vnoise(uv * 31.0);
    float blotch = smoothstep(0.60, 0.74, n) * face;
    col = mix(col, col * vec3(0.50, 0.55, 0.40), blotch);

    // Darkened eye sockets: stretched gaussian band as a darkener
    vec2 e = vec2(uFaceCenter.x, uFaceCenter.y - 0.35 * uFaceScale);
    vec2 k = uv - e;
    k.x *= aspect * 0.6;
    float sigma = 0.32 * uFaceScale;
    float w = exp(-dot(k, k) / (sigma * sigma));
    col *= 1.0 - 0.55 * w;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform float uTime;

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

    // Frost mask grows inward from the edges, broken up by noise
    vec2 d = uv - vec2(0.5);
    d.x *= aspect;
    float r = length(d);
    float n = 0.6 * vnoise(uv * 9.0) + 0.4 * vnoise(uv * 23.0);
    float mask = smoothstep(0.20, 0.60, r + (n - 0.5) * 0.45);
    float frost = mask * smoothstep(0.30, 0.85, n);

    // Refraction under the frost: nudge the single tap by a noise gradient
    vec2 off = vec2(vnoise(uv * 40.0) - 0.5,
                    vnoise(uv * 40.0 + 17.0) - 0.5) * 0.015 * mask;
    vec3 col = texture(uTexture, clamp(uv + off, 0.0, 1.0)).rgb;

    // Cold grade with blue-lifted shadows
    float l = lum(col);
    col = mix(vec3(l), col, 0.7) * vec3(0.80, 0.95, 1.25);
    col += vec3(0.0, 0.02, 0.06) * (1.0 - l);

    // Whiten under the frost
    col = mix(col, vec3(0.85, 0.93, 1.0), 0.85 * frost);

    // Twinkling glints inside the frost mask
    vec2 cell = floor(uv * 90.0);
    float h = rand(cell);
    float glint = pow(rand(cell + 7.0), 40.0);
    float twinkle = 0.5 + 0.5 * sin(uTime * 3.0 + h * 6.2831);
    col += vec3(1.0) * glint * twinkle * mask * 3.0;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

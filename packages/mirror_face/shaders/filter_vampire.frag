#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform vec2 uFaceCenter;
uniform float uFaceScale;

out vec4 fragColor;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float aspect = uResolution.x / uResolution.y;

    vec3 col = texture(uTexture, uv).rgb;

    // Bone-pale grade: heavy desaturation, lifted midtones, cool cast
    float l = lum(col);
    col = mix(vec3(l), col, 0.35);
    col = pow(clamp(col, 0.0, 1.0), vec3(0.85)) * vec3(0.98, 0.97, 1.03);

    // Red eye band, weighted by darkness so the tint hugs the eyes
    vec2 e = vec2(uFaceCenter.x, uFaceCenter.y - 0.35 * uFaceScale);
    vec2 k = uv - e;
    k.x *= aspect * 0.6;
    float sigma = 0.32 * uFaceScale;
    float w = exp(-dot(k, k) / (sigma * sigma));
    float dark = 0.35 + 0.65 * smoothstep(0.55, 0.15, l);
    col = mix(col, vec3(0.60, 0.05, 0.08), 0.9 * w * dark);

    // Deep red-black vignette + mild contrast lift
    vec2 d = uv - vec2(0.5);
    d.x *= aspect;
    float vig = smoothstep(0.42, 0.9, length(d));
    col = mix(col, vec3(0.08, 0.0, 0.02), vig);
    col = mix(vec3(0.5), col, 1.1);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

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

    // Eye band sits above the face center; one horizontally stretched bulge
    // covers both eyes.
    vec2 e = vec2(uFaceCenter.x, uFaceCenter.y - 0.35 * uFaceScale);
    vec2 d = uv - e;
    d.x *= aspect;

    vec2 k = d;
    k.x *= 0.6;  // widen the kernel horizontally into a band
    float sigma = 0.35 * uFaceScale;
    float w = exp(-dot(k, k) / (sigma * sigma));

    // Sampling closer to the band center magnifies the eyes
    vec2 src = d * (1.0 - 0.25 * w);
    src.x /= aspect;
    vec2 wUV = clamp(e + src, 0.0, 1.0);

    vec3 col = texture(uTexture, wUV).rgb;

    // Brighten + pastel: mild desaturation with a faint pink cast
    col = pow(clamp(col, 0.0, 1.0), vec3(0.85));
    float l = lum(col);
    col = mix(vec3(l), col, 0.8) + vec3(0.04, 0.01, 0.03);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

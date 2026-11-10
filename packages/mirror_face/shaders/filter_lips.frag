#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform vec2 uFaceCenter;
uniform float uFaceScale;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float aspect = uResolution.x / uResolution.y;
    float R = uFaceScale;

    // Mouth sits below the face center; one horizontally stretched bulge
    // covers the lips (same band trick as doll uses for the eyes).
    vec2 m = vec2(uFaceCenter.x, uFaceCenter.y + 0.42 * R);
    vec2 d = uv - m;
    d.x *= aspect;

    vec2 k = d;
    k.x *= 0.65;  // widen the kernel into a lip-shaped band
    float sigma = 0.22 * R;
    float w = exp(-dot(k, k) / (sigma * sigma));

    // Subtle magnification — fuller, still pretty.
    vec2 src = d * (1.0 - 0.18 * w);
    src.x /= aspect;
    vec2 wUV = clamp(m + src, 0.0, 1.0);

    vec3 col = texture(uTexture, wUV).rgb;

    // Faint warmth confined to the lens so lips read a touch rosier.
    col *= mix(vec3(1.0), vec3(1.06, 0.98, 0.98), w * 0.6);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

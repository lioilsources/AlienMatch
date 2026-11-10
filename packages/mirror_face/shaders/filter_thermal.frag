#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;

out vec4 fragColor;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 thermalPalette(float t) {
    // black → blue → cyan → green → yellow → red → white
    t = clamp(t, 0.0, 1.0);
    if (t < 0.17) return mix(vec3(0.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0),   t / 0.17);
    if (t < 0.33) return mix(vec3(0.0, 0.0, 1.0), vec3(0.0, 1.0, 1.0),   (t - 0.17) / 0.16);
    if (t < 0.50) return mix(vec3(0.0, 1.0, 1.0), vec3(0.0, 1.0, 0.0),   (t - 0.33) / 0.17);
    if (t < 0.67) return mix(vec3(0.0, 1.0, 0.0), vec3(1.0, 1.0, 0.0),   (t - 0.50) / 0.17);
    if (t < 0.83) return mix(vec3(1.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0),   (t - 0.67) / 0.16);
                  return mix(vec3(1.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0),   (t - 0.83) / 0.17);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float l = lum(texture(uTexture, uv).rgb);

    // Sensor noise
    float noise = (rand(uv * 137.0) - 0.5) * 0.03;
    vec3 col = thermalPalette(clamp(l + noise, 0.0, 1.0));

    fragColor = vec4(col, 1.0);
}

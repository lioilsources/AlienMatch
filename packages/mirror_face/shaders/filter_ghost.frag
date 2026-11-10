#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform float uTime;

out vec4 fragColor;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float aspect = uResolution.x / uResolution.y;

    // Spectral wobble
    vec2 wUV = uv + vec2(sin(uv.y * 8.0 + uTime * 1.7),
                         cos(uv.x * 6.0 + uTime * 1.3)) * 0.009;
    wUV = clamp(wUV, 0.0, 1.0);

    // Double exposure: main tap plus a slowly drifting echo
    vec3 c1 = texture(uTexture, wUV).rgb;
    vec2 echoUV = clamp(wUV + vec2(0.02 * sin(uTime * 0.9), -0.038), 0.0, 1.0);
    vec3 c2 = texture(uTexture, echoUV).rgb;
    vec3 col = max(c1, 0.75 * c2);

    // Pale spectral blue, lifted
    float l = lum(col);
    col = mix(vec3(l), col, 0.1) * vec3(0.75, 0.85, 1.0);
    col = pow(clamp(col, 0.0, 1.0), vec3(0.8));

    // Breathing brightness; edges fade away
    col *= 0.88 + 0.12 * sin(uTime * 2.0);
    vec2 d = uv - vec2(0.5);
    d.x *= aspect;
    col *= 1.0 - 0.6 * smoothstep(0.45, 0.9, length(d));

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

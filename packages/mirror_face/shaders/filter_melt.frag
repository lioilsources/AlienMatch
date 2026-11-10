#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform float uTime;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;

    // Downward drip: sag grows toward the bottom, ripples across x and time.
    float sag = (0.06 + 0.05 * sin(uv.x * 18.0 + uTime * 1.5))
              * smoothstep(0.15, 1.0, uv.y);
    float s = sag * (0.6 + 0.4 * sin(uTime * 0.7 + uv.x * 7.0));

    // Sample above the fragment so the image appears to slump; per-channel
    // offsets give a vertical chromatic fringe.
    float r = texture(uTexture, clamp(vec2(uv.x, uv.y - s * 1.15), 0.0, 1.0)).r;
    float g = texture(uTexture, clamp(vec2(uv.x, uv.y - s), 0.0, 1.0)).g;
    float b = texture(uTexture, clamp(vec2(uv.x, uv.y - s * 0.85), 0.0, 1.0)).b;
    vec3 col = vec3(r, g, b);

    // Slow warm/cool oscillation
    float osc = sin(uTime * 0.5) * 0.06;
    col *= vec3(1.0 + osc, 1.0, 1.0 - osc);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

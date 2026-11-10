#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform vec2 uFaceCenter;
uniform float uFaceScale;

out vec4 fragColor;

// Giraffe treatment: the head shrinks, the neck stretches. Same piecewise
// vertical remap idea as alien, opposite directions.
void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float aspect = uResolution.x / uResolution.y;
    float R = uFaceScale;

    float dx = uv.x - uFaceCenter.x;
    float dy = uv.y - uFaceCenter.y;

    // Confine horizontally so background columns beside the body stay stable.
    float gx = exp(-(dx * dx * aspect * aspect) / (1.8 * R * R));

    // Head (above the chin): sample wider -> smaller head on screen.
    float headMask = smoothstep(0.45 * R, -0.2 * R, dy);
    float srcY = uFaceCenter.y + dy * (1.0 + 0.35 * headMask);
    float srcX = uFaceCenter.x + dx * (1.0 + 0.28 * headMask * gx);

    // Neck (below the chin): sample closer -> stretched long on screen.
    float neckMask = smoothstep(0.45 * R, 1.4 * R, dy);
    srcY = uFaceCenter.y + (srcY - uFaceCenter.y) * (1.0 - 0.40 * neckMask);

    srcY = mix(uv.y, srcY, gx);
    srcX = mix(uv.x, srcX, gx);

    vec2 wUV = clamp(vec2(srcX, srcY), 0.0, 1.0);
    fragColor = vec4(texture(uTexture, wUV).rgb, 1.0);
}

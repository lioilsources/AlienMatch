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

    float dx = uv.x - uFaceCenter.x;
    float dy = uv.y - uFaceCenter.y;

    // Forehead: compressed source coords -> stretched on screen.
    // Chin: expanded source coords -> squashed on screen.
    float srcY;
    if (dy < 0.0) {
        srcY = uFaceCenter.y + dy * (1.0 - 0.35 * smoothstep(0.0, uFaceScale, -dy));
    } else {
        srcY = uFaceCenter.y + dy * (1.0 + 0.30 * smoothstep(0.0, 0.8 * uFaceScale, dy));
    }

    // Confine horizontally so background columns beside the head stay stable
    float gx = exp(-(dx * dx * aspect * aspect) / (uFaceScale * uFaceScale));
    srcY = mix(uv.y, srcY, gx);

    // Taper the cranium: sample slightly wider toward the top
    float taper = smoothstep(0.0, uFaceScale, -dy) * gx;
    float srcX = uFaceCenter.x + dx * (1.0 + 0.12 * taper);

    vec2 wUV = clamp(vec2(srcX, srcY), 0.0, 1.0);
    vec3 col = texture(uTexture, wUV).rgb;

    // Slight desaturation with a green cast on midtones
    float l = lum(col);
    col = mix(vec3(l), col, 0.75);
    float mid = smoothstep(0.15, 0.5, l) * (1.0 - smoothstep(0.6, 0.95, l));
    col *= mix(vec3(1.0), vec3(0.92, 1.10, 0.92), mid * 0.6);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

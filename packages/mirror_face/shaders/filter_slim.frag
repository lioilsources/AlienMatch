#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform vec2 uFaceCenter;
uniform float uFaceScale;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float aspect = uResolution.x / uResolution.y;

    float dx = uv.x - uFaceCenter.x;
    float dy = uv.y - uFaceCenter.y;

    // Gaussian windows confine the pinch to the face so the frame edges and
    // background stay put. Sampling wider renders the face narrower.
    float gy = exp(-(dy * dy) / (2.0 * uFaceScale * uFaceScale));
    float gx = exp(-(dx * dx * aspect * aspect) / (uFaceScale * uFaceScale));
    float srcX = uFaceCenter.x + dx * (1.0 + 0.18 * gy * gx);

    vec2 wUV = clamp(vec2(srcX, uv.y), 0.0, 1.0);

    // Light 3x3 bilateral smooth on the warped sample
    vec2 px = 1.5 / uResolution;
    vec3 center = texture(uTexture, wUV).rgb;
    vec3  accum  = vec3(0.0);
    float wTotal = 0.0;
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            vec3  s = texture(uTexture, clamp(wUV + vec2(float(i), float(j)) * px, 0.0, 1.0)).rgb;
            float d = length(s - center);
            float w = exp(-d * d * 12.0);
            accum  += s * w;
            wTotal += w;
        }
    }
    vec3 col = mix(center, accum / wTotal, 0.5);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

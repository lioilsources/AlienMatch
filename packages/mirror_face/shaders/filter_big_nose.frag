#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform vec2 uFaceCenter;
uniform float uFaceScale;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float aspect = uResolution.x / uResolution.y;

    vec2 d = uv - uFaceCenter;
    d.x *= aspect;
    float r = length(d);
    float R = uFaceScale;

    vec2 wUV = uv;
    if (r < R && r > 0.0) {
        // pow < 1 compresses source coords toward the center, magnifying it
        vec2 dn = d * pow(r / R, 0.55);
        // Blend back to identity at the rim so there is no ring seam
        dn = mix(dn, d, smoothstep(0.8 * R, R, r));
        dn.x /= aspect;
        wUV = clamp(uFaceCenter + dn, 0.0, 1.0);
    }

    fragColor = vec4(texture(uTexture, wUV).rgb, 1.0);
}

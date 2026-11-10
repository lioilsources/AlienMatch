#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;

out vec4 fragColor;

vec2 barrelDistort(vec2 uv, float k) {
    vec2 c = uv * 2.0 - 1.0;
    c.x *= uResolution.x / uResolution.y;
    float r2 = dot(c, c);
    c *= 1.0 + k * r2;
    c.x /= (uResolution.x / uResolution.y);
    return c * 0.5 + 0.5;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;

    // Barrel distortion (CRT curvature)
    vec2 wUV = barrelDistort(uv, 0.14);

    // Black bezel outside screen
    if (wUV.x < 0.0 || wUV.x > 1.0 || wUV.y < 0.0 || wUV.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // Chromatic aberration (RGB fringing)
    float ca = 0.0028;
    float r = texture(uTexture, wUV + vec2( ca, 0.0)).r;
    float g = texture(uTexture, wUV              ).g;
    float b = texture(uTexture, wUV - vec2( ca, 0.0)).b;
    vec3 col = vec3(r, g, b);

    // Scanlines: horizontal dark bars every 2 physical rows
    float scan = 0.72 + 0.28 * sin(FlutterFragCoord().y * 3.14159);
    col *= scan;

    // Phosphor warmth: slight green tint on bright areas
    float bright = dot(col, vec3(0.333));
    col *= mix(vec3(1.0), vec3(0.88, 1.12, 0.78), bright * 0.18);

    // Vignette
    vec2 vig = wUV * 2.0 - 1.0;
    float vignette = pow(clamp(1.0 - dot(vig * vec2(0.55, 0.65), vig * vec2(0.55, 0.65)), 0.0, 1.0), 0.7);
    col *= vignette;

    // Compensate for scanline + vignette darkening
    col *= 1.18;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

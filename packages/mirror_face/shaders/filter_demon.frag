#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform float uTime;
uniform vec2 uFaceCenter;
uniform float uFaceScale;

out vec4 fragColor;

float rand(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    float aspect = uResolution.x / uResolution.y;

    // Rising heat shimmer, stronger toward the bottom of the frame
    float amp = 0.0025 * (0.3 + 0.7 * uv.y);
    vec2 sUV = uv;
    sUV.x += sin(uv.y * 40.0 + uTime * 6.0) * amp;
    sUV = clamp(sUV, 0.0, 1.0);

    vec3 col = texture(uTexture, sUV).rgb;

    // Infernal grade
    col *= vec3(1.35, 0.55, 0.45);
    col = pow(clamp(col, 0.0, 1.0), vec3(1.15));

    // Glowing eye band with flicker (additive emissive)
    vec2 e = vec2(uFaceCenter.x, uFaceCenter.y - 0.35 * uFaceScale);
    vec2 k = uv - e;
    k.x *= aspect * 0.6;
    float sigma = 0.28 * uFaceScale;
    float w = exp(-dot(k, k) / (sigma * sigma));
    float flicker = 0.75 + 0.2 * sin(uTime * 9.0) + 0.05 * sin(uTime * 23.0);
    col += vec3(1.0, 0.25, 0.05) * w * flicker * 0.8;

    // Ember sparks confined to the edges
    vec2 d = uv - vec2(0.5);
    d.x *= aspect;
    float r = length(d);
    float edge = smoothstep(0.35, 0.75, r);
    vec2 cell = floor(uv * 120.0) + floor(uTime * 10.0);
    float spark = step(0.995, rand(cell));
    col += vec3(1.0, 0.5, 0.1) * spark * edge;

    // Dark red vignette
    col = mix(col, vec3(0.10, 0.0, 0.0), smoothstep(0.55, 0.95, r));

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

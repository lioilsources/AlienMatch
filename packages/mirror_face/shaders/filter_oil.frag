#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;

out vec4 fragColor;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
    vec2 uv  = FlutterFragCoord().xy / uResolution;
    vec2 px  = 2.0 / uResolution;  // 2-logical-px step for paint texture
    vec3 center = texture(uTexture, uv).rgb;

    // Bilateral-like weighted blur: weight by color similarity to center.
    // Preserves edges (paint boundaries) while smoothing inside regions.
    vec3  accum  = vec3(0.0);
    float wTotal = 0.0;

    for (int i = -2; i <= 2; i++) {
        for (int j = -2; j <= 2; j++) {
            vec3  s = texture(uTexture, uv + vec2(float(i), float(j)) * px).rgb;
            float d = length(s - center);
            float w = exp(-d * d * 18.0);   // high sigma → fast falloff at color edges
            accum  += s * w;
            wTotal += w;
        }
    }

    vec3 col = accum / wTotal;

    // Boost saturation for thick oil-paint look
    float l = lum(col);
    col = mix(vec3(l), col, 1.55);

    // Slight darkening at edges for impasto effect
    float eL = lum(texture(uTexture, uv + vec2(-px.x,  0.0)).rgb);
    float eR = lum(texture(uTexture, uv + vec2( px.x,  0.0)).rgb);
    float eU = lum(texture(uTexture, uv + vec2( 0.0,  px.y)).rgb);
    float eD = lum(texture(uTexture, uv + vec2( 0.0, -px.y)).rgb);
    float edge = sqrt((eR-eL)*(eR-eL) + (eU-eD)*(eU-eD));
    col *= 1.0 - smoothstep(0.08, 0.35, edge) * 0.25;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

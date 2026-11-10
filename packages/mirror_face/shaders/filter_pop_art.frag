#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;

out vec4 fragColor;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

float halftone(vec2 fragCoord, float angle, float cellSize, float value) {
    float cosA = cos(angle), sinA = sin(angle);
    vec2 rot = vec2(fragCoord.x * cosA - fragCoord.y * sinA,
                    fragCoord.x * sinA + fragCoord.y * cosA);
    vec2 cell = floor(rot / cellSize);
    vec2 center = cell * cellSize + cellSize * 0.5;
    float dotR = value * cellSize * 0.5;
    return 1.0 - smoothstep(dotR - 0.8, dotR + 0.8, length(rot - center));
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;
    vec2 px = 1.0 / uResolution;

    vec3 src = texture(uTexture, uv).rgb;

    // CMYK channels from RGB
    float C = 1.0 - src.r;
    float M = 1.0 - src.g;
    float Y = 1.0 - src.b;
    float K = min(C, min(M, Y));
    C = (C - K) / max(1.0 - K, 0.001);
    M = (M - K) / max(1.0 - K, 0.001);
    Y = (Y - K) / max(1.0 - K, 0.001);

    float cellSize = 10.0;
    // Classic CMYK screen angles
    float dotC = halftone(fragCoord, radians(105.0), cellSize, C);
    float dotM = halftone(fragCoord, radians(75.0),  cellSize, M);
    float dotY = halftone(fragCoord, radians(90.0),  cellSize, Y);
    float dotK = halftone(fragCoord, radians(45.0),  cellSize, K);

    // Subtractive CMYK → RGB
    vec3 col;
    col.r = clamp(1.0 - dotC - dotK, 0.0, 1.0);
    col.g = clamp(1.0 - dotM - dotK, 0.0, 1.0);
    col.b = clamp(1.0 - dotY - dotK, 0.0, 1.0);

    // Sobel outlines
    float tl = lum(texture(uTexture, uv + vec2(-px.x,  px.y)).rgb);
    float tc = lum(texture(uTexture, uv + vec2( 0.0,   px.y)).rgb);
    float tr = lum(texture(uTexture, uv + vec2( px.x,  px.y)).rgb);
    float ml = lum(texture(uTexture, uv + vec2(-px.x,  0.0 )).rgb);
    float mr = lum(texture(uTexture, uv + vec2( px.x,  0.0 )).rgb);
    float bl = lum(texture(uTexture, uv + vec2(-px.x, -px.y)).rgb);
    float bcc = lum(texture(uTexture, uv + vec2( 0.0,  -px.y)).rgb);
    float br = lum(texture(uTexture, uv + vec2( px.x, -px.y)).rgb);
    float gx = -tl - 2.0*ml - bl + tr + 2.0*mr + br;
    float gy = -tl - 2.0*tc - tr + bl + 2.0*bcc + br;
    float outline = smoothstep(0.18, 0.45, sqrt(gx*gx + gy*gy));
    col = mix(col, vec3(0.0), outline * 0.9);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}

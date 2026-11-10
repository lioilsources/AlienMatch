#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;

out vec4 fragColor;

float luminance(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

float sobelEdge(vec2 uv, vec2 px) {
    float tl = luminance(texture(uTexture, uv + vec2(-px.x,  px.y)).rgb);
    float tc = luminance(texture(uTexture, uv + vec2( 0.0,   px.y)).rgb);
    float tr = luminance(texture(uTexture, uv + vec2( px.x,  px.y)).rgb);
    float ml = luminance(texture(uTexture, uv + vec2(-px.x,  0.0 )).rgb);
    float mr = luminance(texture(uTexture, uv + vec2( px.x,  0.0 )).rgb);
    float bl = luminance(texture(uTexture, uv + vec2(-px.x, -px.y)).rgb);
    float bc = luminance(texture(uTexture, uv + vec2( 0.0,  -px.y)).rgb);
    float br = luminance(texture(uTexture, uv + vec2( px.x, -px.y)).rgb);
    float gx = -tl - 2.0*ml - bl + tr + 2.0*mr + br;
    float gy = -tl - 2.0*tc - tr + bl + 2.0*bc + br;
    return sqrt(gx*gx + gy*gy);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    vec2 px = 1.0 / uResolution;

    vec3 col = texture(uTexture, uv).rgb;
    float lum = luminance(col);

    float idx = clamp(floor(lum * 4.0), 0.0, 3.0);

    vec3 comicColor;
    if (idx < 0.5)      comicColor = vec3(0.05, 0.02, 0.02);
    else if (idx < 1.5) comicColor = vec3(0.85, 0.15, 0.12);
    else if (idx < 2.5) comicColor = vec3(0.98, 0.88, 0.20);
    else                comicColor = vec3(0.97, 0.97, 0.97);

    float edge = sobelEdge(uv, px);
    float outline = smoothstep(0.18, 0.40, edge);
    comicColor = mix(comicColor, vec3(0.0), outline);

    fragColor = vec4(comicColor, 1.0);
}

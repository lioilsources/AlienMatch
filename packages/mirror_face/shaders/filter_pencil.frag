#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;

out vec4 fragColor;

float luminance(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    vec2 px = 1.0 / uResolution;

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
    float edge = sqrt(gx*gx + gy*gy);

    float strength = smoothstep(0.15, 0.45, edge);
    float pencil = 1.0 - strength;

    fragColor = vec4(vec3(pencil), 1.0);
}

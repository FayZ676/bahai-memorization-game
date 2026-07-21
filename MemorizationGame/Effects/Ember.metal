#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float hash21(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

static float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i), hash21(i + float2(1.0, 0.0)), u.x),
        mix(hash21(i + float2(0.0, 1.0)), hash21(i + float2(1.0, 1.0)), u.x),
        u.y
    );
}

static float fbm(float2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * valueNoise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

static float fbmN(float2 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < octaves; i++) {
        v += a * valueNoise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

constant float bandSoft = 0.10;

static float3 rampColor(float d, float h, float az) {
    float3 c1 = mix(float3(0.24, 0.04, 0.02), float3(0.55, 0.12, 0.04), h);
    float3 c2 = mix(float3(0.51, 0.14, 0.05), float3(0.89, 0.35, 0.11), h);
    float3 c3 = mix(float3(0.75, 0.31, 0.10), float3(0.98, 0.66, 0.24), h);
    float3 c4 = mix(float3(0.92, 0.59, 0.24), float3(1.00, 0.96, 0.84), h);
    c1 = mix(c1, float3(0.03, 0.07, 0.30), az);
    c2 = mix(c2, float3(0.08, 0.24, 0.80), az);
    c3 = mix(c3, float3(0.30, 0.55, 1.00), az);
    c4 = mix(c4, float3(0.85, 0.93, 1.00), az);
    float3 col = c1;
    col = mix(col, c2, smoothstep(0.32 - bandSoft, 0.32 + bandSoft, d));
    col = mix(col, c3, smoothstep(0.56 - bandSoft, 0.56 + bandSoft, d));
    col = mix(col, c4, smoothstep(0.82 - bandSoft, 0.82 + bandSoft, d));
    return col;
}

[[ stitchable ]] half4 emberSurface(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float seed,
    float heat,
    float blue,
    float scale,
    float octaves,
    float warp,
    float speed,
    float sheen,
    float intensity,
    float flameReach
) {
    float2 uv = float2(position.x / size.x, 1.0 - position.y / size.y);

    float I = intensity;
    float az = smoothstep(0.68, 1.0, blue);
    int oct = clamp(int(octaves), 1, 5);

    float r = fract(sin(seed * 12.9898) * 43758.5453);
    float phase = r * 137.0;
    float2 off = float2(r * 37.0, r * 19.0);
    float t = (time + phase) * speed * (0.7 + 0.5 * I);

    float2 pw = float2(uv.x * scale, uv.y * scale * 0.8667 - t * 0.9) + off;
    float w = fbmN(pw * 1.5 + float2(0.0, -t * 0.4), oct);

    float glyph = layer.sample(position).a;

    float fl = 0.0;
    if (flameReach > 0.0) {
        float wob = fbmN(float2(uv.x * 6.0, uv.y * 4.0 - t * 2.0) + float2(w, w) * warp, oct) - 0.5;
        float reach = flameReach * (0.35 + 0.75 * I);
        float jitter = hash21(position + t);
        const int steps = 24;
        for (int k = 1; k <= steps; k++) {
            float fk = float(k) - jitter;
            float frac = fk / float(steps);
            float fade = 1.0 - frac;
            float dance = sin(uv.y * 7.0 - t * 3.0 + w * 6.28) * frac * frac;
            float sway = (wob * 0.34 * frac + dance * 0.18) * size.x;
            float2 s = position + float2(sway, reach * frac * size.y);
            fl = max(fl, float(layer.sample(s).a) * fade);
        }
        float2 pt = float2(uv.x * 7.0, uv.y * 5.0 - t * 2.4);
        float tear = fbmN(pt + float2(w, w) * 1.1 * warp, oct);
        fl *= smoothstep(0.30, 0.72, tear);
        fl *= 0.25 + 0.75 * I;
        fl *= 1.0 - glyph;
    }

    float3 col = rampColor(fl, heat, az);
    float alpha = smoothstep(0.06, 0.20, fl);

    float nf = fbmN(pw + float2(w, w) * 1.2 * warp, oct);
    float dF = 0.62 + 0.38 * smoothstep(0.2, 0.8, nf) + sheen * uv.y;
    float3 fillCol = rampColor(dF, max(heat, 0.55f), az);
    float alive = smoothstep(0.0, 0.10, I);
    fillCol = mix(float3(0.36, 0.34, 0.31), fillCol, alive);

    col = mix(col, fillCol, glyph);
    alpha = max(alpha, glyph * 0.98);

    return half4(half3(col * alpha), half(alpha));
}

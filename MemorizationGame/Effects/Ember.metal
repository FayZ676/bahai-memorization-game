#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
#include "Noise.h"
using namespace metal;

constant float bandSoft = 0.10;
constant float heatShimmer = 0.04;

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

constant float3 azureTint = float3(0.55, 0.75, 1.00);

static float4 coalsLook(float2 uv, float t, float2 off) {
    float2 p = uv * float2(7.0, 2.5) + off;
    float n = valueNoise(p);
    float hotspot = smoothstep(0.55, 0.8, n);
    float pulse = 0.5 + 0.5 * sin(t * 0.7 + hash21(floor(p)) * 6.28);
    float3 bed = mix(float3(0.05, 0.03, 0.025), float3(0.14, 0.05, 0.03), n);
    float3 ember = mix(float3(0.45, 0.08, 0.02), float3(0.90, 0.28, 0.06), pulse);
    return float4(bed + ember * hotspot * (0.35 + 0.65 * pulse), 0.95);
}

static float4 smolderLook(float2 uv, float t, float2 off) {
    float2 p = uv * float2(4.0, 2.0) + off - float2(t * 0.18, t * 0.05);
    float d = smoothstep(0.3, 0.8, fbmN(p, 2));
    float flare = pow(0.5 + 0.5 * sin(t * 0.45 + off.x), 10.0);
    float3 col = mix(float3(0.16, 0.04, 0.02), float3(0.70, 0.20, 0.04), d);
    col += float3(0.6, 0.25, 0.06) * flare * d;
    return float4(col, 0.95);
}

static float4 flameLook(float2 uv, float t, float2 off, float speed, float warp,
                        float flickAmp, float3 c1, float3 c2, float3 c3, float az) {
    float2 p = float2(uv.x * 3.5, uv.y * 2.2 - t * speed) + off;
    float w = fbmN(p * 1.6 + float2(0.0, -t * speed * 0.4), 2);
    float n = fbmN(p + float2(w, w) * warp, 2);
    float flick = (valueNoise(float2(t * (2.0 + speed), off.y)) - 0.5) * 2.0 * flickAmp;
    float d = 0.45 + 0.45 * smoothstep(0.2, 0.8, n) + flick;
    float3 col = c1;
    col = mix(col, c2, smoothstep(0.35, 0.65, d));
    col = mix(col, mix(c3, azureTint, az), smoothstep(0.65, 0.95, d));
    col = mix(col, azureTint, az * smoothstep(0.6, 1.0, uv.y) * d);
    return float4(col, 0.95);
}

static float4 stageLook(int i, float2 uv, float t, float2 off, float az) {
    switch (i) {
    case 0:
        return coalsLook(uv, t, off);
    case 1:
        return smolderLook(uv, t, off);
    case 2:
        return flameLook(uv, t, off, 1.2, 0.8, 0.12,
                         float3(0.50, 0.10, 0.03), float3(0.90, 0.38, 0.08), float3(1.00, 0.68, 0.22), 0.0);
    default:
        return flameLook(uv, t, off, 2.4, 1.3, 0.20,
                         float3(0.95, 0.50, 0.12), float3(1.00, 0.80, 0.35), float3(1.00, 0.96, 0.85), az);
    }
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
    float flameReach,
    float flameRise,
    float flameDetail,
    float stage
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

    float2 hazeUV = float2(uv.x * 9.0, uv.y * 12.0 - t * 2.0);
    float2 haze = float2(fbmN(hazeUV, oct) - 0.5,
                         fbmN(hazeUV + 31.0, oct) - 0.5);
    float2 distort = heatShimmer * size * heat * (0.3 + 0.7 * I);
    float glyph = layer.sample(position + haze * distort).a;

    float fl = 0.0;
    if (flameReach > 0.0) {
        float wob = fbmN(float2(uv.x * 6.0 * flameDetail, uv.y * 4.0 - t * 2.0) + float2(w, w) * warp, oct) - 0.5;
        float rise = flameRise * (0.35 + 0.75 * I);
        float jitter = hash21(position + t);
        const int steps = 24;
        for (int k = 1; k <= steps; k++) {
            float fk = float(k) - jitter;
            float frac = fk / float(steps);
            float fade = 1.0 - frac;
            float dance = sin(uv.y * 7.0 - t * 3.0 + w * 6.28) * frac * frac;
            float sway = (wob * 0.34 * frac + dance * 0.18) * size.x;
            float2 s = position + float2(sway, rise * frac);
            fl = max(fl, float(layer.sample(s).a) * fade);
        }
        float2 pt = float2(uv.x * 7.0 * flameDetail, uv.y * 5.0 - t * 2.4);
        float tear = fbmN(pt + float2(w, w) * 1.1 * warp, oct);
        fl *= smoothstep(0.30, 0.72, tear);
        fl *= 0.25 + 0.75 * I;
        fl *= 1.0 - glyph;
    }

    float3 col = rampColor(fl, heat, az);
    float alpha = smoothstep(0.06, 0.20, fl);

    float3 fillCol;
    float fillAlpha;
    if (stage >= 0.0) {
        float tRaw = time + phase;
        int lo = int(clamp(floor(stage), 0.0, 2.0));
        float f = smoothstep(0.0, 1.0, clamp(stage - float(lo), 0.0, 1.0));
        float4 fill = mix(stageLook(lo, uv, tRaw, off, blue),
                          stageLook(lo + 1, uv, tRaw, off, blue), f);
        fillCol = fill.rgb;
        fillAlpha = fill.a;
    } else {
        float nf = fbmN(pw + float2(w, w) * 1.2 * warp, oct);
        float dF = 0.62 + 0.38 * smoothstep(0.2, 0.8, nf) + sheen * uv.y;
        fillCol = rampColor(dF, max(heat, 0.55f), az);
        float alive = smoothstep(0.0, 0.10, I);
        fillCol = mix(float3(0.36, 0.34, 0.31), fillCol, alive);
        fillAlpha = 0.98;
    }

    col = mix(col, fillCol, glyph);
    alpha = max(alpha, glyph * fillAlpha);

    return half4(half3(col * alpha), half(alpha));
}

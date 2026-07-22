#include <metal_stdlib>
#include "Noise.h"
using namespace metal;

[[ stitchable ]] half4 burnDissolve(
    float2 position,
    half4 color,
    float2 size,
    float progress,
    float seed
) {
    float glyph = color.a;
    if (glyph < 0.004) {
        return color;
    }

    float2 uv = position / size;
    float2 warp = float2(
        fbm(uv * 3.0 + seed * 3.10),
        fbm(uv * 3.0 + seed * 3.10 + 5.2)
    ) - 0.5;
    float2 wuv = uv + warp * 0.38;

    float n = fbm(wuv * float2(4.5, 6.0) + seed * 7.13);
    n = clamp((n - 0.18) / 0.62, 0.0, 1.0);

    float bias = 0.26;
    n = n * (1.0 - bias) + wuv.y * bias;

    float ew = 0.17;
    float t = mix(-ew, 1.0 + ew, progress);

    if (n <= t) {
        return half4(0.0h);
    }

    float f = (n - t) / ew;
    if (f < 1.0) {
        float g = 1.0 - clamp(f, 0.0, 1.0);
        float3 ch = float3(0.06, 0.02, 0.01);
        float3 rd = float3(0.72, 0.13, 0.03);
        float3 og = float3(1.00, 0.46, 0.09);
        float3 wh = float3(1.00, 0.93, 0.72);
        float3 c = mix(ch, rd, smoothstep(0.00, 0.35, g));
        c = mix(c, og, smoothstep(0.30, 0.72, g));
        c = mix(c, wh, smoothstep(0.82, 1.00, g));
        float a = glyph * (0.55 + 0.45 * smoothstep(0.0, 0.25, f));
        return half4(half3(c) * half(a), half(a));
    }

    return color;
}

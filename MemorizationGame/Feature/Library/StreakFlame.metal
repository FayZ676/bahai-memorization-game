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

[[ stitchable ]] half4 weekFire(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    device const float *intensities, int intensityCount,
    device const float *heats, int heatCount,
    device const float *blues, int blueCount,
    device const float *misses, int missCount
) {
    float2 uv = float2(position.x / size.x, 1.0 - position.y / size.y);
    int dayCount = min(min(intensityCount, heatCount), min(blueCount, missCount));
    float columns = float(dayCount);

    float best = 0.0;
    float bestHeat = 0.0;
    float bestInt = 0.0;
    float bestBlue = 0.0;
    float coneD = 0.0;
    float smoke = 0.0;

    for (int i = 0; i < dayCount; i++) {
        float fi = float(i);
        float cx = (fi + 0.5) / columns;

        if (misses[i] > 0.5) {
            float2 sp = float2(uv.x * 6.0 + fi * 7.3, uv.y * 2.4 - time * 0.35);
            float sn = fbm(sp + fbm(sp) * 1.3);
            float sx = (uv.x - cx) * columns + (sn - 0.5) * 2.2 * uv.y;
            float senv = smoothstep(1.0, 0.0, abs(sx) / 0.75);
            smoke = max(smoke, senv * smoothstep(0.85, 0.05, uv.y) * smoothstep(0.38, 0.62, sn));
            continue;
        }

        float I = intensities[i];
        float B = blues[i];
        float live = mix(0.45, 1.0, fi / max(columns - 1.0, 1.0));
        float egy = 0.45 + 0.75 * I;
        float t = time * mix(0.55, 1.25, live) * (0.7 + 0.5 * I);
        float Hm = 0.10 + 0.88 * I;

        float2 pb = float2(uv.x * 7.5 + fi * 13.7, uv.y * 3.4 - t * 1.5);
        float w = fbm(pb * 1.6 + float2(0.0, -t * 0.6));
        float n = fbm(pb + float2(w * 1.4, w * 1.1));

        float yy = uv.y / Hm;
        float dx = (uv.x - cx) * columns / (0.36 + 0.38 * I);

        float sway = fbm(float2(fi * 5.3 + t * 0.5, uv.y * 2.1 - t * 0.9)) - 0.5;
        dx += sway * (0.30 + 1.1 * yy) * live * egy;

        yy += (n - 0.5) * (0.30 + 0.55 * yy) * (0.5 + 0.9 * live) * egy;
        dx += (n - 0.5) * (0.22 + 0.55 * yy) * live * egy;

        float body = clamp(1.0 - yy, 0.0, 1.0);
        float profile = pow(body, 0.55) * (0.62 + 0.38 * body);
        float edgeN = fbm(float2(dx * 2.1 + fi * 9.1, uv.y * 3.0 - t * 1.2));
        float envW = max(0.05, profile * (0.66 + 0.62 * edgeN));
        float env = smoothstep(1.0, 0.0, abs(dx) / envW);
        float vert = pow(body, 1.2);
        float d = vert * env * (0.62 + 0.65 * n);

        float tipness = smoothstep(0.30, 0.85, yy) * (0.55 + 0.45 * I);
        float2 pt = float2(uv.x * 15.0 + fi * 7.1, uv.y * 6.5 - t * (2.2 + 2.2 * I));
        float tear = fbm(pt + float2(w * 1.2, w * 0.8));
        d *= mix(1.0, smoothstep(0.28, 0.60, tear) * 1.45, tipness);

        float sputter = mix(
            smoothstep(0.35, 0.75, valueNoise(float2(t * 0.9 + fi * 3.1, fi * 2.7))),
            1.0, smoothstep(0.05, 0.28, I));
        d *= sputter;
        d *= 0.45 + 0.72 * I;

        if (d > best) {
            best = d;
            bestHeat = heats[i];
            bestInt = I;
            bestBlue = B;
        }

        if (B > 0.001) {
            float Hb = Hm * (0.20 + 0.34 * B);
            float yb = uv.y / Hb;
            float dxb = (uv.x - cx) * columns / (0.20 + 0.18 * I);
            yb += (n - 0.5) * 0.40 * yb;
            dxb += (n - 0.5) * 0.35 * yb;
            float vb = clamp(1.0 - yb, 0.0, 1.0);
            float wb = pow(vb, 0.6) * (0.78 + 0.44 * edgeN);
            float eb = smoothstep(1.0, 0.0, abs(dxb) / max(0.05, wb));
            float db = vb * eb * (0.70 + 0.50 * n) * B;
            coneD = max(coneD, db);
        }
    }

    float az = smoothstep(0.68, 1.0, bestBlue);
    float3 col = rampColor(best, bestHeat, az);
    float alpha = smoothstep(0.08, 0.22, best);
    alpha += 0.05 * best;

    if (coneD > 0.001) {
        float3 b1 = float3(0.04, 0.10, 0.42);
        float3 b2 = float3(0.12, 0.32, 0.95);
        float3 b3 = float3(0.60, 0.78, 1.00);
        float3 bcol = b1;
        bcol = mix(bcol, b2, smoothstep(0.42 - bandSoft, 0.42 + bandSoft, coneD));
        bcol = mix(bcol, b3, smoothstep(0.74 - bandSoft, 0.74 + bandSoft, coneD));
        float coneMask = smoothstep(0.24, 0.40, coneD);
        col = mix(col, bcol, coneMask);
        alpha = max(alpha, coneMask * 0.95);
    }

    float sparkAmt = smoothstep(0.85, 1.0, bestInt);
    if (sparkAmt > 0.0) {
        float2 sg = float2(uv.x * 90.0, uv.y * 46.0 - time * 16.0);
        float sp = step(0.997, hash21(floor(sg)));
        sp *= smoothstep(0.03, 0.10, best) * (1.0 - smoothstep(0.22, 0.38, best));
        sp *= sparkAmt;
        col = mix(col, mix(float3(1.0, 0.86, 0.58), float3(0.70, 0.84, 1.0), az), sp);
        alpha = max(alpha, sp * 0.9);
    }

    float smokeA = smoke * 0.20 * (1.0 - alpha);
    col = mix(col, float3(0.52, 0.50, 0.47), smokeA / max(0.001, alpha + smokeA));
    alpha = max(alpha, smokeA);
    alpha = clamp(alpha, 0.0, 1.0);

    return half4(half3(col * alpha), half(alpha));
}

[[ stitchable ]] half4 burningNumber(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float intensity,
    float heat,
    float blue
) {
    float2 uv = float2(position.x / size.x, 1.0 - position.y / size.y);

    float I = intensity;
    float az = smoothstep(0.68, 1.0, blue);
    float t = time * (0.7 + 0.5 * I);

    float2 pw = float2(uv.x * 3.0, uv.y * 2.6 - t * 0.9);
    float w = fbm(pw * 1.5 + float2(0.0, -t * 0.4));

    float glyph = layer.sample(position).a;

    float wob = fbm(float2(uv.x * 6.0, uv.y * 4.0 - t * 2.0) + float2(w, w)) - 0.5;
    float reachStep = 0.034 * (0.35 + 0.75 * I);
    float fl = 0.0;
    for (int k = 1; k <= 8; k++) {
        float fk = float(k);
        float fade = 1.0 - fk / 8.0;
        float2 s = position + float2(wob * 0.14 * (fk / 8.0) * size.x, reachStep * fk * size.y);
        fl = max(fl, float(layer.sample(s).a) * fade);
    }
    float2 pt = float2(uv.x * 7.0, uv.y * 5.0 - t * 2.4);
    float tear = fbm(pt + float2(w, w) * 1.1);
    fl *= smoothstep(0.30, 0.72, tear);
    fl *= 0.25 + 0.75 * I;
    fl *= 1.0 - glyph;

    float3 col = rampColor(fl, heat, az);
    float alpha = smoothstep(0.06, 0.20, fl);

    float nf = fbm(pw + float2(w, w) * 1.2);
    float dF = 0.62 + 0.38 * smoothstep(0.2, 0.8, nf);
    float3 fillCol = rampColor(dF, max(heat, 0.55f), az);
    float alive = smoothstep(0.0, 0.10, I);
    fillCol = mix(float3(0.36, 0.34, 0.31), fillCol, alive);

    col = mix(col, fillCol, glyph);
    alpha = max(alpha, glyph * 0.98);

    return half4(half3(col * alpha), half(alpha));
}

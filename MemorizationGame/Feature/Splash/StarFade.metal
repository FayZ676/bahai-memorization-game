#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

[[ stitchable ]] half4 starFade(float2 position, half4 color, float2 size,
                                float4 front, float4 shape) {
    float heightFraction = clamp((position.y / size.y - shape.x) / shape.y, 0.0, 1.0);
    float shift = front.z * sin(6.283185307179586 * (heightFraction + front.w));
    float reach = (position.x / size.x - (front.x + shift)) / front.y;

    float alpha;
    if (reach <= 0.0) {
        alpha = 1.0;
    } else if (reach >= 1.0) {
        alpha = 0.0;
    } else if (reach < shape.z) {
        alpha = mix(1.0, shape.w, reach / shape.z);
    } else {
        alpha = mix(shape.w, 0.0, (reach - shape.z) / (1.0 - shape.z));
    }

    return color * half(alpha);
}

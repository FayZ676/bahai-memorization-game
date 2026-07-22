#pragma once
#include <metal_stdlib>
using namespace metal;

float hash21(float2 p);
float valueNoise(float2 p);
float fbm(float2 p);
float fbmN(float2 p, int octaves);

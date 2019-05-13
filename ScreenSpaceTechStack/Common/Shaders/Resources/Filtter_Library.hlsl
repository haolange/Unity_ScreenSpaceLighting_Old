#ifndef _Filtter_Library_
#define _Filtter_Library_

#include "Common.hlsl"


//////Color filter
inline half HdrWeight4(half3 Color, half Exposure)
{
    return rcp(Luma4(Color) * Exposure + 4);
}

inline half HdrWeightY(half Color, half Exposure)
{
    return rcp(Color * Exposure + 4);
}

inline half3 RGBToYCoCg(half3 RGB)
{
    half Y = dot(RGB, half3(1, 2, 1));
    half Co = dot(RGB, half3(2, 0, -2));
    half Cg = dot(RGB, half3(-1, 2, -1));

    half3 YCoCg = half3(Y, Co, Cg);
    return YCoCg;
}

inline half3 YCoCgToRGB(half3 YCoCg)
{
    half Y = YCoCg.x * 0.25;
    half Co = YCoCg.y * 0.25;
    half Cg = YCoCg.z * 0.25;

    half R = Y + Co - Cg;
    half G = Y + Cg;
    half B = Y - Co - Cg;

    half3 RGB = half3(R, G, B);
    return RGB;
}

//////Sharpe filter
half4 Sharpe(sampler2D sharpColor, half sharpness, half2 Resolution, half2 UV)
{
    half2 step = 1 / Resolution.xy;

    half3 texA = tex2D(sharpColor, UV + half2(-step.x, -step.y) * 1.5);
    half3 texB = tex2D(sharpColor, UV + half2(step.x, -step.y) * 1.5);
    half3 texC = tex2D(sharpColor, UV + half2(-step.x, step.y) * 1.5);
    half3 texD = tex2D(sharpColor, UV + half2(step.x, step.y) * 1.5);

    half3 around = 0.25 * (texA + texB + texC + texD);
    half4 center = tex2D(sharpColor, UV);

    half3 color = center.rgb + (center.rgb - around) * sharpness;
    return half4(color, center.a);
}

half4 Sharpfilter(Texture2D ColorTexture, SamplerState sampler_ColorTexture, half2 UV, half2 TexelSize, half Sharpness)
{
    half2 Stepsize = 1.0 / TexelSize.xy;

    half3 texA = ColorTexture.SampleLevel( sampler_ColorTexture, UV + half2( -Stepsize.x, -Stepsize.y) * 1.5, 0.0 );
    half3 texB = ColorTexture.SampleLevel( sampler_ColorTexture, UV + half2(  Stepsize.x, -Stepsize.y) * 1.5, 0.0 );
    half3 texC = ColorTexture.SampleLevel( sampler_ColorTexture, UV + half2( -Stepsize.x,  Stepsize.y) * 1.5, 0.0 );
    half3 texD = ColorTexture.SampleLevel( sampler_ColorTexture, UV + half2(  Stepsize.x,  Stepsize.y) * 1.5, 0.0 );

    half3 aroundColor = 0.25 * (texA + texB + texC + texD);
    half4 centerColor = ColorTexture.SampleLevel(sampler_ColorTexture, UV, 0.0);

    half3 color = centerColor.rgb + max(0.0, (centerColor.rgb - aroundColor) * Sharpness );
    return half4(color, centerColor.a);
}

//////Bilateral filter
#define Blur_Sharpness 0.15
#define Blur_Size 3.0
half CrossBilateralWeight(float Sharpness, float4 originColor, float4 blurColor)
{
    half3 Variance = originColor - blurColor;
    return 0.39894 * exp( -0.5 * dot(Variance, Variance) / (Sharpness * Sharpness) ) / Sharpness;
}

half4 Bilateralfilter(sampler2D ColorTexture, half2 uv, half2 TexelSize)
{

    half weight = 0.0, Num_Weight = 0.0;
    half4 blurColor = 0.0, final_Color = 0.0;
    float4 originColor = tex2D(ColorTexture, uv);

    [unroll]
    for (int i = -Blur_Size; i <= Blur_Size; i++)
    {
        [unroll]
        for (int j = -Blur_Size; j <= Blur_Size; j++)
        {
            half2 blurUV = uv * TexelSize + half2(i, j);
            blurColor = tex2Dlod( ColorTexture, half4(blurUV / TexelSize, 0.0, 0.0) );
            weight = CrossBilateralWeight(Blur_Sharpness, originColor, blurColor);
            Num_Weight += weight;
            final_Color += weight * blurColor;
        }
    }
    return final_Color / Num_Weight;
}

half4 Bilateralfilter(Texture2D ColorTexture, SamplerState sampler_ColorTexture, half2 uv, half2 TexelSize)
{

    half weight = 0.0, Num_Weight = 0.0;
    half4 blurColor = 0.0, final_Color = 0.0;
    float4 originColor = ColorTexture.SampleLevel( sampler_ColorTexture, uv, 0.0);

    [unroll]
    for (int i = -Blur_Size; i <= Blur_Size; i++)
    {
        [unroll]
        for (int j = -Blur_Size; j <= Blur_Size; j++)
        {
            half2 blurUV = uv * TexelSize + half2(i, j);
            blurColor = ColorTexture.SampleLevel( sampler_ColorTexture, blurUV / TexelSize, 0.0);
            weight = CrossBilateralWeight(Blur_Sharpness, originColor, blurColor);
            Num_Weight += weight;
            final_Color += weight * blurColor;
        }
    }
    return final_Color / Num_Weight;
}

///////////////Temporal filter
#if defined(UNITY_REVERSED_Z)
    #define COMPARE_DEPTH(a, b) step(b, a)
#else
    #define COMPARE_DEPTH(a, b) step(a, b)
#endif

half2 ReprojectedMotionVectorUV(sampler2D _DepthTexture, half2 uv, half2 screenSize)
{
    half neighborhood[9];
    neighborhood[0] = tex2D(_DepthTexture, uv + (int2(-1, -1) / screenSize)).z;
    neighborhood[1] = tex2D(_DepthTexture, uv + (int2(0, -1) / screenSize)).z;
    neighborhood[2] = tex2D(_DepthTexture, uv + (int2(1, -1) / screenSize)).z;
    neighborhood[3] = tex2D(_DepthTexture, uv + (int2(-1, 0) / screenSize)).z;
    neighborhood[5] = tex2D(_DepthTexture, uv + (int2(1, 0) / screenSize)).z;
    neighborhood[6] = tex2D(_DepthTexture, uv + (int2(-1, 1) / screenSize)).z;
    neighborhood[7] = tex2D(_DepthTexture, uv + (int2(0, -1) / screenSize)).z;
    neighborhood[8] = tex2D(_DepthTexture, uv + (int2(1, 1) / screenSize)).z;

    half3 result = half3(0, 0, tex2D(_DepthTexture, uv).z);
    result = lerp(result, half3(-1, -1, neighborhood[0]), COMPARE_DEPTH(neighborhood[0], result.z));
    result = lerp(result, half3(0, -1, neighborhood[1]), COMPARE_DEPTH(neighborhood[1], result.z));
    result = lerp(result, half3(1, -1, neighborhood[2]), COMPARE_DEPTH(neighborhood[2], result.z));
    result = lerp(result, half3(-1, 0, neighborhood[3]), COMPARE_DEPTH(neighborhood[3], result.z));
    result = lerp(result, half3(1, 0, neighborhood[5]), COMPARE_DEPTH(neighborhood[5], result.z));
    result = lerp(result, half3(-1, 1, neighborhood[6]), COMPARE_DEPTH(neighborhood[6], result.z));
    result = lerp(result, half3(0, -1, neighborhood[7]), COMPARE_DEPTH(neighborhood[7], result.z));
    result = lerp(result, half3(1, 1, neighborhood[8]), COMPARE_DEPTH(neighborhood[8], result.z));

    return (uv + result.xy * screenSize);
}

inline void ResolverAABB(sampler2D currColor, half Sharpness, half ExposureScale, half AABBScale, half2 uv, half2 TexelSize, inout half Variance, inout half4 MinColor, inout half4 MaxColor, inout half4 FilterColor)
{
    const int2 SampleOffset[9] = {int2(-1.0, -1.0), int2(0.0, -1.0), int2(1.0, -1.0), int2(-1.0, 0.0), int2(0.0, 0.0), int2(1.0, 0.0), int2(-1.0, 1.0), int2(0.0, 1.0), int2(1.0, 1.0)};
    half4 SampleColors[9];

    for(uint i = 0; i < 9; i++) {
        #if AA_BicubicFilter
            half4 BicubicSize = half4(TexelSize, 1.0 / TexelSize);
            SampleColors[i] = Texture2DSampleBicubic(currColor, uv + ( SampleOffset[i] / TexelSize), BicubicSize.xy, BicubicSize.zw);
        #else
            SampleColors[i] = tex2D( currColor, uv + ( SampleOffset[i] / TexelSize) );
        #endif
    }

    #if AA_Filter
        half SampleWeights[9];
        for(uint j = 0; j < 9; j++) {
            SampleWeights[j] = HdrWeight4(SampleColors[j].rgb, ExposureScale);
        }

        half TotalWeight = 0;
        for(uint k = 0; k < 9; k++) {
            TotalWeight += SampleWeights[k];
        }  
        SampleColors[4] = (SampleColors[0] * SampleWeights[0] + SampleColors[1] * SampleWeights[1] + SampleColors[2] * SampleWeights[2] +  SampleColors[3] * SampleWeights[3] + SampleColors[4] * SampleWeights[4] + SampleColors[5] * SampleWeights[5] +  SampleColors[6] * SampleWeights[6] + SampleColors[7] * SampleWeights[7] + SampleColors[8] * SampleWeights[8]) / TotalWeight;
    #endif

    half4 m1 = 0.0; half4 m2 = 0.0;
    for(uint x = 0; x < 9; x++) {
        m1 += SampleColors[x];
        m2 += SampleColors[x] * SampleColors[x];
    }

    half4 mean = m1 / 9.0;
    half4 stddev = sqrt( (m2 / 9.0) - pow2(mean) );
        
    MinColor = mean - AABBScale * stddev;
    MaxColor = mean + AABBScale * stddev;

    FilterColor = SampleColors[4];
    MinColor = min(MinColor, FilterColor);
    MaxColor = max(MaxColor, FilterColor);

    half4 TotalVariance = 0;
    for(uint z = 0; z < 9; z++) {
        TotalVariance += pow2( Luminance(SampleColors[z]) - Luminance(mean) );
    }
    Variance = saturate( (TotalVariance / 9) * 256 );
    Variance *= FilterColor.a;
}

//////Kuwahara filter
half4 Kuwaharafilter(Texture2D ColorTexture, SamplerState sampler_ColorTexture, in half2 uv, in half2 TexelSize) 
{
    const int half_width = 3.8;
    half2 inv_src_size = 1.0 / TexelSize;
    
    half n = half( (half_width + 1) * (half_width + 1) );
    half inv_n = 1.0 / n;
    
    half sigma2 = 0.0;
    half min_sigma = 100.0;
    half3 col = 0.0, m = 0.0, s = 0.0;
    
    [unroll]
    for (int j = -half_width; j <= 0; ++j) {
        [unroll]
        for (int i = -half_width; i <= 0; ++i) {
            half3 c = ColorTexture.SampleLevel( sampler_ColorTexture, uv + half2(i, j) * inv_src_size, 0.0);
            m += c;
            s += c * c;
        }
    }
    
    m *= inv_n; s = abs(s * inv_n - m * m);
    sigma2 = s.x + s.y + s.z;
    if (sigma2 < min_sigma) {
        min_sigma = sigma2;
        col = m;
    }
    m = 0.0; s = 0.0;
    
    [unroll]
    for (int q = -half_width; q <= 0; ++q) {
        [unroll]
        for (int e = 0; e <= half_width; ++e) {
            half3 c = ColorTexture.SampleLevel( sampler_ColorTexture, uv + half2(e, q) * inv_src_size, 0.0);
            m += c;
            s += c * c;
        }
    }
    
    m *= inv_n;
    s = abs(s * inv_n - m * m);
    
    sigma2 = s.x + s.y + s.z;
    if (sigma2 < min_sigma) {
        min_sigma = sigma2;
        col = m;
    }
    m = 0.0; s = 0.0;
    
    [unroll]
    for (int w = 0; w <= half_width; ++w) {
        [unroll]
        for (int z = 0; z <= half_width; ++z) {
            half3 c = ColorTexture.SampleLevel( sampler_ColorTexture, uv + half2(z, w) * inv_src_size, 0.0);
            m += c;
            s += c * c;
        }
    }
    
    m *= inv_n;
    s = abs(s * inv_n - m * m);
    
    sigma2 = s.x + s.y + s.z;
    if (sigma2 < min_sigma) {
        min_sigma = sigma2;
        col = m;
    }
    m = 0.0; s = 0.0;;
    
    [unroll]
    for (int x = 0; x <= half_width; ++x) {
        [unroll]
        for (int y = -half_width; y <= 0; ++y) {
            half3 c = ColorTexture.SampleLevel( sampler_ColorTexture, uv + half2(y, x) * inv_src_size, 0.0);
            m += c;
            s += c * c;
        }
    }
    
    m *= inv_n;
    s = abs(s * inv_n - m * m);
    
    sigma2 = s.x + s.y + s.z;
    if (sigma2 < min_sigma) {
        min_sigma = sigma2;
        col = m;
    }
    
    return half4(col, 1.0);
}

float4 GetKernelMeanAndVariance(float2 UV, float2 TexelSize, float4 Range, float2x2 RotationMatrix, Texture2D ColorTexture, SamplerState sampler_ColorTexture)
{
    float3 Mean = 0.0;
    float3 Variance = 0.0;
    float Samples = 0.0;
    TexelSize = 1.0 / TexelSize;
    
    for (int x = Range.x; x <= Range.y; x++)
    {
        for (int y = Range.z; y <= Range.w; y++)
        {
            float2 Offset = mul(float2(x, y) * TexelSize, RotationMatrix);
            float3 PixelColor = ColorTexture.SampleLevel( sampler_ColorTexture, UV + Offset, 0.0).rgb;
            Mean += PixelColor;
            Variance += PixelColor * PixelColor;
            Samples++;
        }
    }
    
    Mean /= Samples;
    Variance = Variance / Samples - Mean * Mean;
    float TotalVariance = Variance.r + Variance.g + Variance.b;
    return float4(Mean.r, Mean.g, Mean.b, TotalVariance);
}

float GetPixelAngle(float2 UV, float2 TexelSize, Texture2D ColorTexture, SamplerState sampler_ColorTexture)
{
    TexelSize = 1.0 / TexelSize;
    float GradientX = 0.0;
    float GradientY = 0.0;
    float SobelX[9] = {-1.0, -2.0, -1.0,  0.0, 0.0, 0.0,  1.0, 2.0, 1.0};
    float SobelY[9] = {-1.0,  0.0,  1.0, -2.0, 0.0, 2.0, -1.0, 0.0, 1.0};
    int i = 0.0;
    
    for (int x = -1; x <= 1; x++) 
    {
        for (int y = -1; y <= 1; y++) {
            // 1
            float2 Offset = float2(x, y) * TexelSize;
            float3 PixelColor = ColorTexture.SampleLevel( sampler_ColorTexture, UV + Offset, 0.0).rgb;
            float PixelValue = dot(PixelColor, float3(0.3,0.59,0.11));
            
            // 2
            GradientX += PixelValue * SobelX[i];
            GradientY += PixelValue * SobelY[i];
            i++;
        }
    }
    return atan(GradientY / GradientX);
}

half4 Kuwaharafilter_HQ(Texture2D ColorTexture, SamplerState sampler_ColorTexture, in half2 uv, in half2 TexelSize)
{
    const float XRadius= 4.0, YRadius = 4.0;
    float Angle = GetPixelAngle(uv, TexelSize, ColorTexture, sampler_ColorTexture);
    float2x2 RotationMatrix = float2x2(cos(Angle), -sin(Angle), sin(Angle), cos(Angle));
    
    float4 Range;
    float4 MeanAndVariance[4];

    Range = float4(-XRadius, 0, -YRadius, 0);
    MeanAndVariance[0] = GetKernelMeanAndVariance(uv, TexelSize, Range, RotationMatrix, ColorTexture, sampler_ColorTexture);

    Range = float4(0, XRadius, -YRadius, 0);
    MeanAndVariance[1] = GetKernelMeanAndVariance(uv, TexelSize, Range, RotationMatrix, ColorTexture, sampler_ColorTexture);

    Range = float4(-XRadius, 0, 0, YRadius);
    MeanAndVariance[2] = GetKernelMeanAndVariance(uv, TexelSize, Range, RotationMatrix, ColorTexture, sampler_ColorTexture);

    Range = float4(0, XRadius, 0, YRadius);
    MeanAndVariance[3] = GetKernelMeanAndVariance(uv, TexelSize, Range, RotationMatrix, ColorTexture, sampler_ColorTexture);

    // 1
    float3 FinalColor = MeanAndVariance[0].rgb;
    float MinimumVariance = MeanAndVariance[0].a;

    // 2
    for (int i = 1; i < 4; i++)
    {
        if (MeanAndVariance[i].a < MinimumVariance)
        {
            FinalColor = MeanAndVariance[i].rgb;
            MinimumVariance = MeanAndVariance[i].a;
        }
    }

    return half4(FinalColor, 1.0);
}


#endif




//////Sharpening
/*
    //half4 corners = 4 * (TopLeft + BottomRight) - 2 * filterColor;
    //filterColor += (filterColor - (corners * 0.166667)) * 2.718282 * (Sharpness * 0.25);

    half TotalVariance = 0;
    for(uint z = 0; z < 9; z++)
    {
        TotalVariance += pow2(Luminance(SampleColors[z]) - Luminance(mean));
    }
    Variance = saturate((TotalVariance / 9) * 256) * FilterColor.a;
*/
#ifndef _ImageBasedLighting_
#define _ImageBasedLighting_

#include "BSDF_Library.hlsl"
#include "ShadingModel.hlsl"
//#include "UnityImageBasedLighting.cginc"

//////////////////////////Environment LUT 
half IBL_PBR_Diffuse(half LoH, half NoL, half NoV, half Roughness)
{
	half F90 = lerp( 0, 0.5, Roughness ) + ( 2 * pow2(LoH) * Roughness );
	return F_Schlick(1, F90, NoL) * F_Schlick(1, F90, NoV) * lerp(1, 1 / 0.662, Roughness);
}

half IBL_Defualt_DiffuseIntegrated(half Roughness, half NoV) {
    half3 V;
    V.x = sqrt(1 - NoV * NoV);
    V.y = 0;
    V.z = NoV;

    half r = 0; 
	const uint NumSamples = 2048;

    for (uint i = 0; i < NumSamples; i++) {
        half2 E = Hammersley( i, NumSamples, HaltonSequence(i) ); 
        half4 H = CosineSampleHemisphere(E);
        half3 L = 2 * dot(V, H.xyz) * H.xyz - V;

        half NoL = saturate(L.b);
        half LoH = saturate( dot(L, H.xyz) );
        
        if (NoL > 0) {
            half Diffuse = IBL_PBR_Diffuse(LoH, NoL, NoV, Roughness);
            r += Diffuse;
        }
    }
    return r / NumSamples;
}

half IBL_PBR_Specular_G(half NoL, half NoV, half a) {
    half a2 = pow4(a);
    half GGXL = NoV * sqrt((-NoL * a2 + NoL) * NoL + a2);
    half GGXV = NoL * sqrt((-NoV * a2 + NoV) * NoV + a2);
    return (2 * NoL) / (GGXV + GGXL);
}

half2 IBL_Defualt_SpecularIntegrated(half Roughness, half NoV) {
    half3 V;
    V.x = sqrt(1 - NoV * NoV);
    V.y = 0;
    V.z = NoV;

    half2 r = 0;
	const uint NumSamples = 64;

    for (uint i = 0; i < NumSamples; i++) {
        half2 E = Hammersley(i, NumSamples, HaltonSequence(i)); 
        half4 H = ImportanceSampleGGX(E, Roughness);
        half3 L = 2 * dot(V, H) * H.xyz - V;

        half VoH = saturate(dot(V, H.xyz));
        half NoL = saturate(L.z);
        half NoH = saturate(H.z);

        if (NoL > 0) {
            half G = IBL_PBR_Specular_G(NoL, NoV, Roughness);
            half Gv = G * VoH / NoH;
            half Fc = pow(1 - VoH, 5);
            //r.x += Gv * (1 - Fc);
            r.x += Gv;
            r.y += Gv * Fc;
        }
    }
    return r / NumSamples;
}

half2 IBL_Defualt_SpecularIntegrated_Approx(half Roughness, half NoV) {
    const half4 c0 = half4(-1.0, -0.0275, -0.572,  0.022);
    const half4 c1 = half4( 1.0,  0.0425,  1.040, -0.040);
    half4 r = Roughness * c0 + c1;
    half a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
    return half2(-1.04, 1.04) * a004 + r.zw;
}

half IBL_Defualt_SpecularIntegrated_Approx_Nonmetal(half Roughness, half NoV) {
	const half2 c0 = { -1, -0.0275 };
	const half2 c1 = { 1, 0.0425 };
	half2 r = Roughness * c0 + c1;
	return min( r.x * r.x, exp2( -9.28 * NoV ) ) * r.x + r.y;
}


half2 IBL_Cloth_Ashikhmin_SpecularIntegrated_Approx(half Roughness, half NoV) {
    const half4 c0 = half4(0.24,  0.93, 0.01, 0.20);
    const half4 c1 = half4(2, -1.30, 0.40, 0.03);

    half s = 1 - NoV;
    half e = s - c0.y;
    half g = c0.x * exp2(-(e * e) / (2 * c0.z)) + s * c0.w;
    half n = Roughness * c1.x + c1.y;
    half r = max(1 - n * n, c1.z) * g;

    return half2(r, r * c1.w);
}

half2 IBL_Cloth_Charlie_SpecularIntegrated_Approx(half Roughness, half NoV) {
    const half3 c0 = half3(0.95, 1250, 0.0095);
    const half4 c1 = half4(0.04, 0.2, 0.3, 0.2);

    half a = 1 - NoV;
    half b = 1 - (Roughness);

    half n = pow(c1.x + a, 64);
    half e = b - c0.x;
    half g = exp2(-(e * e) * c0.y);
    half f = b + c1.y;
    half a2 = a * a;
    half a3 = a2 * a;
    half c = n * g + c1.z * (a + c1.w) * Roughness + f * f * a3 * a3 * a2;
    half r = min(c, 18);

    return half2(r, r * c0.z);
}


half3 ImageBasedLighting_Hair(half3 V, float3 N, float3 specularColor, float Roughness, float Scatter) {
	float3 Lighting = 0;
	uint NumSamples = 32;
	
	UNITY_LOOP
	for( uint i = 0; i < NumSamples; i++ ) {
        float2 E = Hammersley(i, NumSamples, HaltonSequence(i));
        float3 L = UniformSampleSphere(E).rgb;
		{
			float PDF = 1 / (4 * PI);
			float InvWeight = PDF * NumSamples;
			float Weight = rcp(InvWeight);

			float3 Shading = 0;
            Shading = Hair_Lit(L, V, N, specularColor, 0.5, Roughness, 0, Scatter, 0, 0);

            Lighting += Shading * Weight;
		}
	}
	return Lighting;
}


//////////Enviornment BRDF
#ifndef Multi_Scatter
	#define Multi_Scatter 1
#endif

half4 PreintegratedDGF_LUT(sampler2D PreintegratedLUT, inout half3 EnergyCompensation, half3 SpecularColor, half Roughness, half NoV)
{
    half3 Enviorfilter_GFD = tex2Dlod( PreintegratedLUT, half4(Roughness, NoV, 0.0, 0.0) ).rgb;
    half3 ReflectionGF = lerp( saturate(50.0 * SpecularColor.g) * Enviorfilter_GFD.ggg, Enviorfilter_GFD.rrr, SpecularColor );

#if Multi_Scatter
    EnergyCompensation = 1.0 + SpecularColor * (1.0 / Enviorfilter_GFD.r - 1.0);
#else
    EnergyCompensation = 1.0;
#endif

    return half4(ReflectionGF, Enviorfilter_GFD.b);
}

half3 PreintegratedGF_ClothAshikhmin(half3 SpecularColor, half Roughness, half NoV)
{
    half2 AB = IBL_Cloth_Ashikhmin_SpecularIntegrated_Approx(Roughness, NoV);
    return SpecularColor * AB.r + AB.g;
}

half3 PreintegratedGF_ClothCharlie(half3 SpecularColor, half Roughness, half NoV)
{
    float2 AB = IBL_Cloth_Charlie_SpecularIntegrated_Approx(Roughness, NoV);
    return SpecularColor * AB.r + AB.g;
}

#endif

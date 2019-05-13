#include "UnityStandardBRDF.cginc"
float HaltonSequence (uint index, uint base = 3) {
	float result = 0;
	float f = 1;
	int i = index;
	
	UNITY_UNROLL
	while (i > 0) {
		f = f / base;
		result = result + f * (i % base);
		i = floor(i / base);
	}
	return result;
}

float2 Hammersley(int i, int N) {
	return float2(float(i) * (1 / float(N)), HaltonSequence(i, 3));
}

float4 ImportanceSampleGGX(float2 E, float Roughness) {
	float m = Roughness * Roughness;
	float m2 = m * m;

	float Phi = 2 * 3.14 * E.x;
	float CosTheta = sqrt((1 - E.y) / ( 1 + (m2 - 1) * E.y));
	float SinTheta = sqrt(1 - CosTheta * CosTheta);

	float3 H;
	H.x = SinTheta * cos(Phi);
	H.y = SinTheta * sin(Phi);
	H.z = CosTheta;
			
	float d = (CosTheta * m2 - CosTheta) * CosTheta + 1;
	float D = m2 / (3.14 * d * d);
			
	float PDF = D * CosTheta;

	return float4(H, PDF);
}

float FresnelSchlickApprox(float F0, float HoV){
    return F0 + (1 - F0) * Pow5(1 - HoV);
}

float Beckmann(float NoH, float Roughness)
{
    float a = Roughness * Roughness;
    float a2 = a * a;
    float NoH2 = NoH * NoH;
    return exp((NoH2 - 1) / (a2 * NoH2)) / (3.14 * a2 * NoH2 * NoH2);
}

float GGX(float NoH, float Roughness)
{
    float a = Roughness * Roughness;
    float a2 = a * a;
    float d = (NoH * a2 - NoH) * NoH + 1;
    return a2 / (3.14 * d * d);
}

float Vis_SmithJointApprox(float NoL, float NoV, float Roughness)
{
    float a = Roughness * Roughness;
    float Vis_SmithV = NoL * (NoV * (1 - a) + a);
    float Vis_SmithL = NoV * (NoL * (1 - a) + a);
    return 0.5 * rcp(Vis_SmithV + Vis_SmithL);
}

float CookTorranceBRDF(float NoH, float NoL, float NoV, float VoH, float roughness)
{
    roughness = clamp(roughness, 0.04, 1);
    float pbr_GGX = GGX(NoH, roughness);
    float pbr_Geometry = Vis_SmithJointApprox(NoL, NoV, roughness);
    float pbr_Fersnel = FresnelSchlickApprox(0.04, VoH);
    return pbr_Geometry * (pbr_GGX * NoL) * pbr_Fersnel;
}

//注意:thetaOut和beta都与纬度无关
float IntegrateGTSO(float alphaV, float beta, float roughness, float thetaRef)
{
    const uint NumSamples = 128;
    float3 V = float3(sin(-thetaRef), 0, cos(thetaRef));
    float3 BN = float3(sin(thetaRef - beta), 0, cos(thetaRef - beta));
    float NoV = V.z;
    float accV = 0;
    float acc = 0;
    float brdf = 0;
    for (uint i = 0; i < NumSamples; i++)
    {
        float2 E = Hammersley(i, NumSamples);
        float4 sample = ImportanceSampleGGX(E, roughness);
        float3 H = sample.xyz;
        float3 L = 2 * dot(V, H) * H - V;

        float NoL = saturate(L.z);
        float NoH = saturate(H.z);
        float VoH = saturate(dot(V, H));
        brdf = CookTorranceBRDF(NoH, NoL, NoV, VoH, roughness);
        if (acos(dot(BN, L)) < alphaV)
        {
            accV += brdf;
        }
        acc += brdf ;
    }
    return accV / acc;
}
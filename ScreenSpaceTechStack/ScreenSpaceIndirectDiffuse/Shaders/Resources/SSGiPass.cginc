#include "UnityCG.cginc"
#include "../../../Common/Shaders/Resources/Include_HLSL.hlsl"

#ifndef AA_Filter
    #define AA_Filter 1
#endif

#ifndef AA_BicubicFilter
    #define AA_BicubicFilter 0
#endif

sampler2D _SSGi_SceneColor_RT, _SSGi_Noise, _SSGi_RayCastRT, _SSGi_TemporalPrev_RT, _SSGi_TemporalCurr_RT, _SSGi_Bilateral_RT,
		  _CameraDepthTexture, _CameraMotionVectorsTexture, _CameraGBufferTexture0, _CameraGBufferTexture1, _CameraGBufferTexture2, _CameraReflectionsTexture;

Texture2D _SSGi_HierarchicalDepth_RT; SamplerState sampler_SSGi_HierarchicalDepth_RT;

int _SSGi_MaskRay, _SSGi_NumSteps_HiZ, _SSGi_NumRays, _SSGi_NumResolver, _SSGi_HiZ_MaxLevel, _SSGi_HiZ_StartLevel, _SSGi_HiZ_StopLevel, _SSGi_HiZ_PrevDepthLevel;

half _SSGi_GiIntensity, _SSGi_ScreenFade, _SSGi_TemporalScale, _SSGi_TemporalWeight, _SSGi_Thickness;

half4 _SSGi_ScreenSize, _SSGi_RayCastSize, _SSGi_NoiseSize, _SSGi_Jitter;

half4x4 _SSGi_ProjectionMatrix, _SSGi_InverseProjectionMatrix, _SSGi_ViewProjectionMatrix, _SSGi_InverseViewProjectionMatrix, _SSGi_LastFrameViewProjectionMatrix, _SSGi_WorldToCameraMatrix, _SSGi_CameraToWorldMatrix, _SSGi_ProjectToPixelMatrix;

struct VertexInput
{
	half4 vertex : POSITION;
	half4 uv : TEXCOORD0;
};

struct PixelInput
{
	half4 vertex : SV_POSITION;
	half4 uv : TEXCOORD0;
};

PixelInput vert(VertexInput v)
{
	PixelInput o;
	o.vertex = v.vertex;
	o.uv = v.uv;
	return o;
}

//---//---//----//----//-------//----//----//----//-----//----//-----//----//----BilateralBlur//---//---//----//----//-------//----//----//----//-----//----//-----//----//----
void GetAo_Depth(sampler2D _SourceTexture, float2 uv, inout float3 AO_RO, inout float AO_Depth)
{
	float4 SourceColor = tex2Dlod(_SourceTexture, float4(uv, 0.0, 0.0));
	AO_RO = SourceColor.xyz;
	AO_Depth = SourceColor.w;
}

float CrossBilateralWeight(float BLUR_RADIUS, float r, float Depth, float originDepth) 
{
	const float BlurSigma = BLUR_RADIUS * 0.5;
	const float BlurFalloff = 1.0 / (2.0 * BlurSigma * BlurSigma);

    float dz = (originDepth - Depth) * _ProjectionParams.z * 0.25;
	return exp2(-r * r * BlurFalloff - dz * dz);
}

void ProcessSample(float4 AO_RO_Depth, float BLUR_RADIUS, float r, float originDepth, inout float3 totalAO_RO, inout float totalWeight)
{
	float weight = CrossBilateralWeight(BLUR_RADIUS, r, originDepth, AO_RO_Depth.w);
	totalWeight += weight;
	totalAO_RO += weight * AO_RO_Depth.xyz;
}

void ProcessRadius(sampler2D _SourceTexture, float2 uv0, float2 deltaUV, float BLUR_RADIUS, float originDepth, inout float3 totalAO_RO, inout float totalWeight)
{
	float r = 1.0;
	float z = 0.0;
	float2 uv = 0.0;
	float3 AO_RO = 0.0;

	UNITY_UNROLL
	for (; r <= BLUR_RADIUS / 2.0; r += 1.0) {
		uv = uv0 + r * deltaUV;
		GetAo_Depth(_SourceTexture, uv, AO_RO, z);
		ProcessSample(float4(AO_RO, z), BLUR_RADIUS, r, originDepth, totalAO_RO, totalWeight);
	}

	UNITY_UNROLL
	for (; r <= BLUR_RADIUS; r += 2.0) {
		uv = uv0 + (r + 0.5) * deltaUV;
		GetAo_Depth(_SourceTexture, uv, AO_RO, z);
		ProcessSample(float4(AO_RO, z), BLUR_RADIUS, r, originDepth, totalAO_RO, totalWeight);
	}
		
}

float4 BilateralBlur(float BLUR_RADIUS, float2 uv0, float2 deltaUV, sampler2D _SourceTexture)
{
	float totalWeight = 1.0;
	float Depth = 0.0;
	float3 totalAOR = 0.0;
	GetAo_Depth(_SourceTexture, uv0, totalAOR, Depth);
		
	ProcessRadius(_SourceTexture, uv0, -deltaUV, BLUR_RADIUS, Depth, totalAOR, totalWeight);
	ProcessRadius(_SourceTexture, uv0, deltaUV, BLUR_RADIUS, Depth, totalAOR, totalWeight);
	
	totalAOR /= totalWeight;
	return float4(totalAOR, Depth);
}

//---//---//----//----//-------//----//----//----//-----//----//-----//----//----BRDF//---//---//----//----//-------//----//----//----//-----//----//-----//----//----
half SSR_BRDF(half3 V, half3 L, half3 N, half Roughness)
{
	half3 H = normalize(L + V);

	half NoH = max(dot(N, H), 0);
	half NoL = max(dot(N, L), 0);
	half NoV = max(dot(N, V), 0);

	half D = D_GGX(NoH, Roughness);
	half G = Vis_SmithGGXCorrelated(NoL, NoV, Roughness);

	return max(0, D * G);
}

////////////////////////////////-----Get Hierarchical_ZBuffer-----------------------------------------------------------------------------
float Hierarchical_ZBuffer(PixelInput i) : SV_Target {
	float2 uv = i.uv.xy;
		
    half4 minDepth = half4(
        _SSGi_HierarchicalDepth_RT.SampleLevel( sampler_SSGi_HierarchicalDepth_RT, uv, _SSGi_HiZ_PrevDepthLevel, int2(-1.0,-1.0) ).r,
        _SSGi_HierarchicalDepth_RT.SampleLevel( sampler_SSGi_HierarchicalDepth_RT, uv, _SSGi_HiZ_PrevDepthLevel, int2(-1.0, 1.0) ).r,
        _SSGi_HierarchicalDepth_RT.SampleLevel( sampler_SSGi_HierarchicalDepth_RT, uv, _SSGi_HiZ_PrevDepthLevel, int2(1.0, -1.0) ).r,
        _SSGi_HierarchicalDepth_RT.SampleLevel( sampler_SSGi_HierarchicalDepth_RT, uv, _SSGi_HiZ_PrevDepthLevel, int2(1.0, 1.0) ).r
    );

	return max( max(minDepth.r, minDepth.g), max(minDepth.b, minDepth.a) );
}

////////////////////////////////-----RayTrace Sampler-----------------------------------------------------------------------------
float4 SSGi_RayTracing(PixelInput i) : SV_Target
{
	float2 UV = i.uv.xy;

	float SceneDepth = tex2Dlod(_CameraDepthTexture, float4(UV, 0, 0)).r;
	float EyeDepth = LinearEyeDepth(SceneDepth);
	float LinearDepth = Linear01Depth(SceneDepth);

	half Roughness = clamp(1 - tex2D(_CameraGBufferTexture1, UV).a, 0.02, 1);
	float3 WorldNormal = tex2D(_CameraGBufferTexture2, UV) * 2 - 1;
	float3 ViewNormal = mul((float3x3)(_SSGi_WorldToCameraMatrix), WorldNormal);

	float3 ScreenPos = GetScreenSpacePos(UV, SceneDepth);
	float3 WorldPos = GetWorldSpacePos(ScreenPos, _SSGi_InverseViewProjectionMatrix);
	float3 ViewPos = GetViewSpacePos(ScreenPos, _SSGi_InverseProjectionMatrix);
	float3 ViewDir = GetViewDir(WorldPos, ViewPos);

	float3x3 TangentBasis = GetTangentBasis( WorldNormal );
	//uint3 p1 = Rand3DPCG16( uint3( (float)0xffba * abs(WorldPos) ) );
	//uint2 p = (uint2(UV * 3) ^ 0xa3c75a5cu) ^ (p1.xy);

	//-----Consten Property-------------------------------------------------------------------------
	half Out_Mask = 0;
	half3 Out_Color = 0;
	
	[loop]
	for (uint i = 0; i < (uint)_SSGi_NumRays; i++)
	{
		//-----Trace Dir-----------------------------------------------------------------------------
		//uint3 Random = Rand3DPCG16( int3( p, ReverseBits32(i) ) );
		//half2 Hash = float2(Random.xy ^ Random.z) / 0xffffu;     
		half2 Hash = tex2Dlod(_SSGi_Noise, half4((UV + sin( i + _SSGi_Jitter.zw )) * _SSGi_RayCastSize.xy / _SSGi_NoiseSize.xy, 0, 0)).xy;

		float3 L;
		L.xy = UniformSampleDiskConcentric( Hash );
		L.z = sqrt( 1 - dot( L.xy, L.xy ) );
		float3 World_L = mul( L, TangentBasis );
		float3 View_L = mul((float3x3)(_SSGi_WorldToCameraMatrix),  World_L);

		float3 rayStart = float3(UV, ScreenPos.z);
		float4 rayProj = mul ( _SSGi_ProjectionMatrix, float4(ViewPos + View_L, 1.0) );
		float3 rayDir = normalize( (rayProj.xyz / rayProj.w) - ScreenPos);
		rayDir.xy *= 0.5;

		float4 RayHitData = Hierarchical_Z_Trace(_SSGi_HiZ_MaxLevel, _SSGi_HiZ_StartLevel, _SSGi_HiZ_StopLevel, _SSGi_NumSteps_HiZ, _SSGi_Thickness, 1 / _SSGi_RayCastSize.xy, rayStart, rayDir, _SSGi_HierarchicalDepth_RT, sampler_SSGi_HierarchicalDepth_RT);

		float3 SampleColor = tex2Dlod(_SSGi_SceneColor_RT, half4(RayHitData.xy, 0, 0));
		float4 SampleNormal = tex2Dlod(_CameraGBufferTexture2, half4(RayHitData.xy, 0, 0)) * 2 - 1;
		float Occlusion = 1 - saturate( dot(World_L, SampleNormal) ); 

		SampleColor *= Occlusion;
		SampleColor *= rcp( 1 + Luminance(SampleColor) );

		Out_Color += SampleColor;
		Out_Mask += Square( RayHitData.a * GetScreenFadeBord(RayHitData.xy, _SSGi_ScreenFade) );
	}
	Out_Color /= _SSGi_NumRays;
	Out_Color *= rcp( 1 - Luminance(Out_Color) );
	Out_Mask /= _SSGi_NumRays;

	//-----Output-----------------------------------------------------------------------------
	[branch]
	if(_SSGi_MaskRay == 1) {
		return half4( Out_Color * saturate(Out_Mask * 2), EyeDepth );
	} else {
		return half4( Out_Color, EyeDepth );
	}
}

////////////////////////////////-----Temporal Sampler-----------------------------------------------------------------------------
half4 Temporalfilter(PixelInput i) : SV_Target
{
	half2 UV = i.uv.xy;
	half3 WorldNormal = tex2D(_CameraGBufferTexture2, UV).rgb * 2 - 1;
	half2 Velocity = tex2D(_CameraMotionVectorsTexture, UV);

	/////Get AABB ClipBox
	half SS_Indirect_Variance = 0;
	half4 SS_Indirect_CurrColor = 0;
	half4 SS_Indirect_MinColor, SS_Indirect_MaxColor;
	ResolverAABB(_SSGi_RayCastRT, 0, 10, _SSGi_TemporalScale, UV, _SSGi_ScreenSize.xy, SS_Indirect_Variance, SS_Indirect_MinColor, SS_Indirect_MaxColor, SS_Indirect_CurrColor);

	/////Clamp TemporalColor
	half4 SS_Indirect_PrevColor = tex2D(_SSGi_TemporalPrev_RT, UV - Velocity);
	SS_Indirect_PrevColor = clamp(SS_Indirect_PrevColor, SS_Indirect_MinColor, SS_Indirect_MaxColor);

	/////Combine TemporalColor
	half Temporal_BlendWeight = saturate(_SSGi_TemporalWeight * (1 - length(Velocity) * 2));
	half4 SS_IndirectColor = lerp(SS_Indirect_CurrColor, SS_Indirect_PrevColor, Temporal_BlendWeight);

	return SS_IndirectColor;
}

////////////////////////////////-----Bilatral Sampler-----------------------------------------------------------------------------
float4 Bilateralfilter_X(PixelInput i) : SV_Target
{
	half2 UV = i.uv.xy;
	const float Radius = 12.0;
	return BilateralBlur( Radius, UV, half2(1.0 / _SSGi_ScreenSize.x, 0), _SSGi_TemporalPrev_RT );
}

float4 Bilateralfilter_Y(PixelInput i) : SV_Target
{
	half2 UV = i.uv.xy;
	const float Radius = 12.0;
	return BilateralBlur( Radius, UV, half2(0, 1.0 / _SSGi_ScreenSize.y), _SSGi_TemporalPrev_RT );
}

////////////////////////////////-----Combine_CombineIndirectDiffuse-----------------------------------------------------------------------------
half3 Combine_IndirectDiffuse(PixelInput i) : SV_Target {
	half2 UV = i.uv.xy;

	half3 BaseColor = tex2D(_CameraGBufferTexture0, UV);
	half3 SceneColor = tex2D(_SSGi_SceneColor_RT, UV);
	half3 ReflectionColor = tex2D(_CameraReflectionsTexture, UV);
	half3 DeferredLighting = SceneColor - ReflectionColor;
	half3 DirectIrradiance = DeferredLighting / BaseColor;
	half3 IndirectIrradiance = tex2D(_SSGi_Bilateral_RT, UV) * _SSGi_GiIntensity;

	return (IndirectIrradiance * BaseColor) + DeferredLighting + ReflectionColor;
}

////////////////////////////////-----DeBug_CombineIndirectDiffuse-----------------------------------------------------------------------------
half3 DeBug_CombineIndirectDiffuse(PixelInput i) : SV_Target
{
	half2 UV = i.uv.xy;
	half3 BaseColor = tex2D(_CameraGBufferTexture0, UV);
	half3 IndirectIrradiance = tex2D(_SSGi_Bilateral_RT, UV);
	return IndirectIrradiance * _SSGi_GiIntensity;
}
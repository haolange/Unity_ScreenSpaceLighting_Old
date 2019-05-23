Shader "GTAO/GroundTruthSpecularOcclusion_LookUpTable"
{

	CGINCLUDE
		#include "UnityCG.cginc"
		#include "UnityCustomRenderTexture.cginc"
		#include "../../../../Common/Shaders/Resources/Include_HLSL.hlsl"

		float IntegrateGTSO(float alphaV, float beta, float Roughness, float thetaRef)
		{
			float3 V = float3( sin(-thetaRef), 0.0, cos(thetaRef) );
			float NoV = V.z;
			float3 BentNormal = float3(sin(thetaRef - beta), 0.0, cos(thetaRef - beta));

			float accV = 0, acc = 0;

			const uint NumSamples = 128;

			for (uint i = 0; i < NumSamples; i++)
			{
				float2 E = Hammersley( i, NumSamples, HaltonSequence(i) ); 
				float4 H = ImportanceSampleGGX(E, Roughness);
				float3 L = 2 * dot(V, H.xyz) * H.xyz - V;

				float NoL = saturate(L.z);
				float NoH = saturate(H.z);
				float VoH = saturate( dot(V, H.xyz) );

				half pbr_GGX = D_GGX(NoH, Roughness);     
				half pbr_Vis = Vis_SmithGGXCorrelated(NoL, NoV, Roughness); 
				half pbr_Fresnel = F_Schlick(0.04, 1.0, VoH);     
    			half BRDF = max( 0, (pbr_Vis * pbr_GGX) * pbr_Fresnel );

				if ( acos(dot(BentNormal, L)) < alphaV )
				{
					accV += BRDF;
				}
				acc += BRDF;
			}

			return accV / acc;
		}

		float4 frag_Integrated_SSRO(v2f_customrendertexture i) : SV_TARGET
		{
			#if 1
				float3 uvw = i.localTexcoord.xyz;
				
				float thetaRef = uvw.x * 3.14 * 0.5;
				float Roughness = clamp(0.1, 1, uvw.y);

				float split = floor(uvw.z * 32);
				float cellZ = (split + 0.5) / 32.0;
				float cellW = uvw.z * 32 - split;
				float alphaV = 3.14 * 0.5 * cellZ;
				float beta = 3.14 * cellW;


				float GTSO_LUT = IntegrateGTSO(alphaV, beta, Roughness, thetaRef);
				return GTSO_LUT;
			#else
				float2 uv = i.localTexcoord.xy;
				float  alphaV = uv.x * 3.14 * 0.5;
				float thetaRef = uv.y * 3.14 * 0.5;
				float GTSO_LUT = IntegrateGTSO(alphaV, thetaRef, 1, thetaRef);
				return GTSO_LUT;
			#endif
		}
	ENDCG
	SubShader
	{
		ZTest Always
		Cull Off
		ZWrite Off

		Pass 
		{ 
			Name "SystemLUT_SSRO"
			CGPROGRAM 
				#pragma vertex CustomRenderTextureVertexShader
				#pragma fragment frag_Integrated_SSRO
			ENDCG 
		}


	}
}


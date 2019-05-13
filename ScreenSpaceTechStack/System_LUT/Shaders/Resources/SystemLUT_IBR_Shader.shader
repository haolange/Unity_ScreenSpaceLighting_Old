Shader "CGBull/SystemLUT/SystemLUT_IBR_Shader" {
    Properties {

    }
	CGINCLUDE
		#include "UnityCG.cginc"
		#include "UnityCustomRenderTexture.cginc"
		#include "Assets/TP/CGBull/Common/Shaders/Resources/Include_HLSL.hlsl"

//////////////PBR Integrated_GFD
		half3 frag_Integrated_GFD (v2f_customrendertexture i) : SV_Target {
			half2 uv = i.localTexcoord.xy;

			half DiffuseD = IBL_Defualt_DiffuseIntegrated(uv.x, uv.y);
			half2 ReflectionGF = IBL_Defualt_SpecularIntegrated(uv.x, uv.y);

			return half3(ReflectionGF, DiffuseD);
		}
	ENDCG
	SubShader {
		Pass {
			Name "PBR_Integrated_GFD"
			CGPROGRAM
				#pragma vertex CustomRenderTextureVertexShader
				#pragma fragment frag_Integrated_GFD
			ENDCG
		}
	}
}

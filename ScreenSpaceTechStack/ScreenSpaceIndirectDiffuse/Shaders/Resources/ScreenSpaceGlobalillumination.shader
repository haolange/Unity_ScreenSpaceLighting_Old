Shader "Hidden/ScreenSpaceGlobalillumination" {

	CGINCLUDE
		#include "SSGiPass.cginc"
	ENDCG

	SubShader {
		ZTest Always 
		ZWrite Off
		Cull Front

		Pass 
		{
			Name"Pass_HierarchicalZBuffer_Pass"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment Hierarchical_ZBuffer
			ENDCG
		} 

		Pass 
		{
			Name"Pass_Hierarchical_ZTrace_Sampler"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment SSGi_RayTracing
			ENDCG
		} 

		Pass 
		{
			Name"Pass_Temporalfilter"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment Temporalfilter
			ENDCG
		} 

		Pass 
		{
			Name"Pass_Bilateralfilter_X"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment Bilateralfilter_X
			ENDCG
		} 

		Pass 
		{
			Name"Pass_Bilateralfilter_Y"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment Bilateralfilter_Y
			ENDCG
		} 

		Pass 
		{
			Name"Pass_CombineIndirectDiffuse"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment Combine_IndirectDiffuse
			ENDCG
		}

		Pass 
		{
			Name"Pass_DeBug_CombineIndirectDiffuse"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment DeBug_CombineIndirectDiffuse
			ENDCG
		}
		
	}
}

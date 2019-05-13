Shader "Hidden/StochasticScreenSpaceReflection" {

	CGINCLUDE
		#include "SSRPass.cginc"
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
			Name"Pass_Linear_2DTrace_SingleSampler"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment Linear_2DTrace_SingleSPP
			ENDCG
		} 

		Pass 
		{
			Name"Pass_Hierarchical_ZTrace_SingleSampler"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment Hierarchical_ZTrace_SingleSPP
				//#pragma fragment TestSSGi_SingleSPP
			ENDCG
		} 

		Pass 
		{
			Name"Pass_Linear_2DTrace_MultiSampler"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment Linear_2DTrace_MultiSPP
			ENDCG
		} 

		Pass 
		{
			Name"Pass_Hierarchical_ZTrace_MultiSampler"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment Hierarchical_ZTrace_MultiSPP
				//#pragma fragment TestSSGi_MultiSPP
			ENDCG
		} 

		Pass 
		{
			Name"Pass_Spatiofilter_SingleSampler"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment Spatiofilter_SingleSPP
			ENDCG
		} 

		Pass 
		{
			Name"Pass_Spatiofilter_MultiSampler"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment Spatiofilter_MultiSPP
			ENDCG
		} 


		Pass 
		{
			Name"Pass_Temporalfilter_SingleSampler"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment Temporalfilter_SingleSPP
			ENDCG
		} 

		Pass 
		{
			Name"Pass_Temporalfilter_MultiSampler"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment Temporalfilter_MultiSPP
			ENDCG
		} 

		Pass 
		{
			Name"Pass_CombineReflection"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment CombineReflectionColor
			ENDCG
		}

		Pass 
		{
			Name"Pass_DeBug_SSRColor"
			CGPROGRAM
				#pragma vertex vert
				#pragma fragment DeBug_SSRColor
			ENDCG
		}
		
	}
}

Shader "Hidden/GroundTruthAmbientOcclusion"
{
	CGINCLUDE
		#include "GTAO_Pass.cginc"
	ENDCG

	SubShader
	{
		ZTest Always
		Cull Off
		ZWrite Off

		Pass 
		{ 
			//////0
			Name"ResolveGTAO"
			CGPROGRAM 
				#pragma vertex vert
				#pragma fragment ResolveGTAO_frag
			ENDCG 
		}

		Pass 
		{ 
			//////1
			Name" UpsamplingGTAO"
			CGPROGRAM 
				#pragma vertex vert
				#pragma fragment UpsamplingGTAO_frag
			ENDCG 
		}

		Pass 
		{ 
			//////2
			Name"SpatialGTAO_X"
			CGPROGRAM 
				#pragma vertex vert
				#pragma fragment SpatialGTAO_X_frag
			ENDCG 
		}

		Pass 
		{ 
			//////3
			Name"SpatialGTAO_Y"
			CGPROGRAM 
				#pragma vertex vert
				#pragma fragment SpatialGTAO_Y_frag
			ENDCG 
		}

		Pass 
		{ 
			//////4
			Name"TemporalGTAO"
			CGPROGRAM 
				#pragma vertex vert
				#pragma fragment TemporalGTAO_frag
			ENDCG 
		}

		Pass 
		{ 
			//////5
			Name"CombienGTAO"
			CGPROGRAM 
				#pragma vertex vert
				#pragma fragment CombienGTAO_frag
			ENDCG 
		}

		Pass 
		{ 
			//////6
			Name"DeBugGTAO"
			CGPROGRAM 
				#pragma vertex vert
				#pragma fragment DeBugGTAO_frag
			ENDCG 
		}

		Pass 
		{ 
			//////7
			Name"DeBugGTRO"
			CGPROGRAM 
				#pragma vertex vert
				#pragma fragment DeBugGTRO_frag
			ENDCG 
		}

	}
}


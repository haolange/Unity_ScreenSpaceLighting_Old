#include "GTAO_Common.cginc"

//////Resolve Pass
half3 ResolveGTAO_frag(PixelInput IN) : SV_Target
{
	half2 uv = IN.uv.xy;

	half SSAODepth = 0;
	half4 GT_Details = GTAO(uv, (int)_SSAO_DirSampler, (int)_SSAO_SliceSampler, SSAODepth);

	half3 BentNormal = mul((half3x3)_SSAO_CameraToWorldMatrix, half3(GT_Details.rg, -GT_Details.b));
	half3 WorldNormal = tex2D(_CameraGBufferTexture2, uv).rgb * 2 - 1;
	half4 Specular = tex2D(_CameraGBufferTexture1, uv);
	half Roughness = 1 - Specular.a;
	half SceneDepth = tex2D(_CameraDepthTexture, uv).r;
	half4 WorldPos = mul(_SSAO_InverseViewProjectionMatrix, half4(half3(uv * 2 - 1, SceneDepth), 1));
	WorldPos.xyz /= WorldPos.w;
	half3 ViewDir = normalize(WorldPos.xyz - _WorldSpaceCameraPos.rgb);
	half3 ReflectionDir = reflect(ViewDir, WorldNormal);

	//half GTRO = ReflectionOcclusion_LUT(uv, GT_Details.a, Roughness, BentNormal);
	half GTRO = ReflectionOcclusion(BentNormal, ReflectionDir, Roughness, 0.5);
	half GTAO = lerp(1, GT_Details.a, _SSAO_Intensity);

	return half3(GTAO, pow2(GTRO), SSAODepth);
} 

//////Bilateral upsample
half3 UpsamplingGTAO_frag(PixelInput IN) : SV_Target
{
	half2 UV = IN.uv.xy;
	half2 SamplerSize = _SSAO_ScreenSize.zw;

	half SceneDepth = tex2D(_CameraDepthTexture, UV).r;
	half LinearDepth = Linear01Depth(SceneDepth);
	half EyeDepth = LinearEyeDepth(SceneDepth);
	half3 WorldNormal = tex2D(_CameraGBufferTexture2, UV);

				
	float4 TopLeft_Color = tex2D( _SSAO_Occlusion_RT, UV );
	float4 TopRight_Color = tex2D( _SSAO_Occlusion_RT, UV + ( float2(0.0, 1.0) / SamplerSize ) );
	float4 BottomLeft_Color = tex2D( _SSAO_Occlusion_RT, UV + ( float2(1.0, 0.0) / SamplerSize ) );
	float4 BottomRight_Color = tex2D( _SSAO_Occlusion_RT, UV + ( float2(1.0, 1.0) / SamplerSize ) );

	float TopLeft_Depth = LinearEyeDepth( tex2D( _CameraDepthTexture, UV ).r );
	float TopRight_Depth = LinearEyeDepth( tex2D( _CameraDepthTexture, UV + ( float2(0.0, 1.0) / SamplerSize ) ).r );
	float BottomLeft_Depth = LinearEyeDepth( tex2D( _CameraDepthTexture, UV + ( float2(1.0, 0.0) / SamplerSize ) ).r );
	float BottomRight_Depth = LinearEyeDepth( tex2D( _CameraDepthTexture, UV + ( float2(1.0, 1.0) / SamplerSize ) ).r );
				
	//float4 offsetDepths = float4(TopLeft_Color.z, TopRight_Color.z, BottomLeft_Color.z, BottomRight_Color.z);	
	float4 offsetDepths = float4(TopLeft_Depth, TopRight_Depth, BottomLeft_Depth, BottomRight_Depth);	
	float4 weights = saturate( 1.0 - abs(offsetDepths - EyeDepth) );
				
	float2 fractCoord = frac(UV * SamplerSize);
				
	float4 filteredX0 = lerp(TopLeft_Color * weights.x, TopRight_Color * weights.y, fractCoord.x);
	float4 filteredX1 = lerp(BottomRight_Color * weights.w, BottomLeft_Color * weights.z, fractCoord.x);
	float4 filtered = lerp(filteredX0, filteredX1, fractCoord.y);
		
	return float3(filtered.rg, EyeDepth);
}

//////Spatial filter
half3 SpatialGTAO_X_frag(PixelInput IN) : SV_Target
{
	half2 uv = IN.uv.xy;
	half3 AOR = BilateralBlur(uv, half2(_SSAO_ScreenSize.x, 0));
	return AOR;
} 

half3 SpatialGTAO_Y_frag(PixelInput IN) : SV_Target
{
	half2 uv = IN.uv.xy;
	half3 AOR = BilateralBlur(uv, half2(0, _SSAO_ScreenSize.y));
	return AOR;
} 

//////Temporal filter
half2 TemporalGTAO_frag(PixelInput IN) : SV_Target
{
	half2 uv = IN.uv.xy;
	half2 velocity = tex2D(_CameraMotionVectorsTexture, uv);

	half SSAO_Variance = 0;
	half4 filterColor = 0;
	half4 minColor, maxColor;
	ResolverAABB(_SSAO_Spatial_RT, 0, 0, _SSAO_TemporalScale, uv, _SSAO_TexelSize.zw, SSAO_Variance, minColor, maxColor, filterColor);

	half4 currColor = filterColor;
	half4 lastColor = tex2D(_SSAO_TemporalPrev_RT, uv - velocity);
	lastColor = clamp(lastColor, minColor, maxColor);

	half weight = saturate(_SSAO_TemporalWeight * (1 - length(velocity) * 8));
	half4 temporalColor = lerp(currColor, lastColor, weight);

	return temporalColor.rg;
}

//////Combien Scene Color
half3 CombienGTAO_frag(PixelInput IN) : SV_Target
{
	half2 uv = IN.uv.xy;

	//////AO & MultiBounce
	half2 GT_Occlusion = tex2D(_SSAO_TemporalCurr_RT, uv).rg;
	//half2 GT_Occlusion = Sharpe(_SSAO_TemporalCurr_RT, 1, _SSAO_TexelSize.zw, uv).rg;
	half3 GTAO = GT_Occlusion.r;
	half GTRO = GT_Occlusion.g;

	if (_SSAO_MultiBounce == 1) {
		half3 Albedo = tex2D(_CameraGBufferTexture0, uv);
		GTAO = MultiBounce(GTAO, Albedo);
	}

	half3 RelfectionColor = tex2D(_CameraReflectionsTexture, uv).rgb;
	half3 SceneColor = GTAO * (tex2D(_SSAO_SceneColor_RT, uv) - RelfectionColor);
	RelfectionColor *= GTRO;

	return half4(SceneColor + RelfectionColor, GTRO);
}

//////DeBug AO
half3 DeBugGTAO_frag(PixelInput IN) : SV_Target
{
	half2 UV = IN.uv.xy;

	//////AO & MultiBounce
	half3 GTAO = tex2D(_SSAO_TemporalCurr_RT, UV).r;
	//half3 GTAO = Sharpe(_SSAO_TemporalCurr_RT, 0.5, _SSAO_TexelSize.zw, UV).r;
	//half3 GTAO = Texture2DSampleBicubic(_SSAO_TemporalCurr_RT, UV, _SSAO_ScreenSize.zw, _SSAO_ScreenSize.xy).r;

	if (_SSAO_MultiBounce == 1) {
		half3 Albedo = tex2D(_CameraGBufferTexture0, UV);
		GTAO = MultiBounce(GTAO, Albedo);
	}

	return GTAO;
}

//////DeBug RO
half3 DeBugGTRO_frag(PixelInput IN) : SV_Target
{
	half2 uv = IN.uv.xy;

	//////AO & MultiBounce
	half GTRO = tex2D(_SSAO_TemporalCurr_RT, uv).g;
	return GTRO;
}
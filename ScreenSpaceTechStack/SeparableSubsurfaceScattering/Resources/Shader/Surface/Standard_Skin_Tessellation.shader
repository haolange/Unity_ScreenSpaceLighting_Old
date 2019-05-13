// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "CGBull/CharacterRender/SeparableSubsurfaceScatter/Surface/Standard_Skin_Tessellation"
{
	Properties
	{
		[Toggle(_USEALBEDOTEXTURE_ON)] _UseAlbedoTexture("UseAlbedoTexture", Float) = 1
		_AlbedoColor("AlbedoColor", Color) = (1,1,1,0)
		_AlbedoTexture("AlbedoTexture", 2D) = "white" {}
		_NormalIntencity("NormalIntencity", Range( 0 , 6)) = 0
		_NormalTexture("NormalTexture", 2D) = "bump" {}
		[Toggle(_USEMETALLICTEXTURE_ON)] _UseMetallicTexture("UseMetallicTexture", Float) = 1
		_Metallic("Metallic", Range( 0 , 1)) = 0
		_MetallicTexture("MetallicTexture", 2D) = "white" {}
		[Toggle(_USEROUGHNESSTEXTURE_ON)] _UseRoughnessTexture("UseRoughnessTexture", Float) = 1
		_Roughness("Roughness", Range( 0 , 1)) = 0
		_RoughnessTexture("RoughnessTexture", 2D) = "white" {}
		_AO_Min("AO_Min", Range( 0 , 1)) = 0
		_AO_Max("AO_Max", Range( 0 , 1)) = 0
		_AmbientOcclusion("AmbientOcclusion", 2D) = "white" {}
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
		[HideInInspector] __dirty( "", Int ) = 1
	}

	SubShader
	{
		Tags{ "RenderType" = "Opaque"  "Queue" = "Geometry+0" }
		LOD 200
		Cull Back
		Stencil
		{
			Ref 5
			Comp Always
			Pass Replace
		}
		CGPROGRAM
		#include "UnityStandardUtils.cginc"
		#pragma target 5.0
		#pragma shader_feature _USEALBEDOTEXTURE_ON
		#pragma shader_feature _USEMETALLICTEXTURE_ON
		#pragma shader_feature _USEROUGHNESSTEXTURE_ON
		#pragma surface surf Standard keepalpha addshadow fullforwardshadows 
		struct Input
		{
			float2 uv_texcoord;
		};

		uniform float _NormalIntencity;
		uniform sampler2D _NormalTexture;
		uniform float4 _NormalTexture_ST;
		uniform float4 _AlbedoColor;
		uniform sampler2D _AlbedoTexture;
		uniform float4 _AlbedoTexture_ST;
		uniform float _Metallic;
		uniform sampler2D _MetallicTexture;
		uniform float4 _MetallicTexture_ST;
		uniform float _Roughness;
		uniform sampler2D _RoughnessTexture;
		uniform float4 _RoughnessTexture_ST;
		uniform float _AO_Min;
		uniform float _AO_Max;
		uniform sampler2D _AmbientOcclusion;
		uniform float4 _AmbientOcclusion_ST;

		void surf( Input i , inout SurfaceOutputStandard o )
		{
			float2 uv_NormalTexture = i.uv_texcoord * _NormalTexture_ST.xy + _NormalTexture_ST.zw;
			o.Normal = UnpackScaleNormal( tex2D( _NormalTexture, uv_NormalTexture ), _NormalIntencity );
			float2 uv_AlbedoTexture = i.uv_texcoord * _AlbedoTexture_ST.xy + _AlbedoTexture_ST.zw;
			#ifdef _USEALBEDOTEXTURE_ON
				float4 staticSwitch4 = tex2D( _AlbedoTexture, uv_AlbedoTexture );
			#else
				float4 staticSwitch4 = _AlbedoColor;
			#endif
			o.Albedo = staticSwitch4.rgb;
			float4 temp_cast_1 = (_Metallic).xxxx;
			float2 uv_MetallicTexture = i.uv_texcoord * _MetallicTexture_ST.xy + _MetallicTexture_ST.zw;
			#ifdef _USEMETALLICTEXTURE_ON
				float4 staticSwitch9 = ( _Metallic * tex2D( _MetallicTexture, uv_MetallicTexture ) );
			#else
				float4 staticSwitch9 = temp_cast_1;
			#endif
			o.Metallic = staticSwitch9.r;
			float temp_output_3_0 = ( 1.0 - _Roughness );
			float4 temp_cast_3 = (temp_output_3_0).xxxx;
			float2 uv_RoughnessTexture = i.uv_texcoord * _RoughnessTexture_ST.xy + _RoughnessTexture_ST.zw;
			#ifdef _USEROUGHNESSTEXTURE_ON
				float4 staticSwitch7 = ( temp_output_3_0 * tex2D( _RoughnessTexture, uv_RoughnessTexture ) );
			#else
				float4 staticSwitch7 = temp_cast_3;
			#endif
			o.Smoothness = staticSwitch7.r;
			float2 uv_AmbientOcclusion = i.uv_texcoord * _AmbientOcclusion_ST.xy + _AmbientOcclusion_ST.zw;
			float lerpResult19 = lerp( _AO_Min , _AO_Max , tex2D( _AmbientOcclusion, uv_AmbientOcclusion ).r);
			o.Occlusion = lerpResult19;
			o.Alpha = 1;
		}

		ENDCG
	}
	Fallback "Mobile/Diffuse"
	CustomEditor "ASEMaterialInspector"
}
/*ASEBEGIN
Version=15600
7;29;1906;1044;1509.951;388.5038;1.328178;True;False
Node;AmplifyShaderEditor.RangedFloatNode;2;-1050.717,536.5583;Float;False;Property;_Roughness;Roughness;9;0;Create;True;0;0;False;0;0;0.43;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;8;-904.3417,197.8793;Float;False;Property;_Metallic;Metallic;6;0;Create;True;0;0;False;0;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;6;-916.2167,623.058;Float;True;Property;_RoughnessTexture;RoughnessTexture;10;0;Create;True;0;0;False;0;None;678687e6283200047ae673c1222a5a19;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.OneMinusNode;3;-782.7167,541.5583;Float;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;10;-924.3417,286.8793;Float;True;Property;_MetallicTexture;MetallicTexture;7;0;Create;True;0;0;False;0;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;13;-771,41;Float;False;Property;_NormalIntencity;NormalIntencity;3;0;Create;True;0;0;False;0;0;1;0;6;0;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;11;-479.7166,797.558;Float;True;Property;_AmbientOcclusion;AmbientOcclusion;13;0;Create;True;0;0;False;0;None;1c702b23c4b924648b3585f7f77af4eb;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;17;-611.938,606.5411;Float;False;2;2;0;FLOAT;0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;21;-457.938,715.5411;Float;False;Property;_AO_Min;AO_Min;11;0;Create;True;0;0;False;0;0;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;5;-694.1708,-359.7635;Float;False;Property;_AlbedoColor;AlbedoColor;1;0;Create;True;0;0;False;0;1,1,1,0;1,1,1,0;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;18;-624.538,263.7415;Float;False;2;2;0;FLOAT;0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;20;-455.938,636.5411;Float;False;Property;_AO_Max;AO_Max;12;0;Create;True;0;0;False;0;0;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;1;-780.1708,-187.7634;Float;True;Property;_AlbedoTexture;AlbedoTexture;2;0;Create;True;0;0;False;0;None;163db8200b9921647b309f6005fd9135;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;12;-465,-4;Float;True;Property;_NormalTexture;NormalTexture;4;0;Create;True;0;0;False;0;None;a6aeef83de2b12540a15c8efd6040a5f;True;0;True;bump;Auto;True;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.StaticSwitch;9;-466.3417,198.8793;Float;False;Property;_UseMetallicTexture;UseMetallicTexture;5;0;Create;True;0;0;False;0;0;1;0;True;;Toggle;2;Key0;Key1;9;1;COLOR;0,0,0,0;False;0;COLOR;0,0,0,0;False;2;COLOR;0,0,0,0;False;3;COLOR;0,0,0,0;False;4;COLOR;0,0,0,0;False;5;COLOR;0,0,0,0;False;6;COLOR;0,0,0,0;False;7;COLOR;0,0,0,0;False;8;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.StaticSwitch;4;-445.1709,-254.7634;Float;False;Property;_UseAlbedoTexture;UseAlbedoTexture;0;0;Create;True;0;0;False;0;0;1;1;True;;Toggle;2;Key0;Key1;9;1;COLOR;0,0,0,0;False;0;COLOR;0,0,0,0;False;2;COLOR;0,0,0,0;False;3;COLOR;0,0,0,0;False;4;COLOR;0,0,0,0;False;5;COLOR;0,0,0,0;False;6;COLOR;0,0,0,0;False;7;COLOR;0,0,0,0;False;8;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.LerpOp;19;-136.938,647.5411;Float;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.StaticSwitch;7;-469.2166,539.0583;Float;False;Property;_UseRoughnessTexture;UseRoughnessTexture;8;0;Create;True;0;0;False;0;0;1;0;True;;Toggle;2;Key0;Key1;9;1;COLOR;0,0,0,0;False;0;COLOR;0,0,0,0;False;2;COLOR;0,0,0,0;False;3;COLOR;0,0,0,0;False;4;COLOR;0,0,0,0;False;5;COLOR;0,0,0,0;False;6;COLOR;0,0,0,0;False;7;COLOR;0,0,0,0;False;8;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.StandardSurfaceOutputNode;0;470,-52;Float;False;True;7;Float;ASEMaterialInspector;200;0;Standard;CGBull/CharacterRender/SeparableSubsurfaceScatter/Surface/Standard_Skin_Tessellation;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;Back;0;False;-1;0;False;-1;False;0;False;-1;0;False;-1;False;0;Opaque;0.5;True;True;0;False;Opaque;;Geometry;All;True;True;True;True;True;True;True;True;True;True;True;True;True;True;True;True;True;0;False;-1;True;5;False;-1;255;False;-1;255;False;-1;7;False;-1;3;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;False;0;15;10;25;True;0.5;True;0;0;False;-1;0;False;-1;0;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;0;0,0,0,0;VertexOffset;True;False;Cylindrical;False;Relative;200;Mobile/Diffuse;-1;-1;-1;-1;0;False;0;0;False;-1;-1;0;False;-1;0;0;0;16;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT;0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT;0;False;9;FLOAT;0;False;10;FLOAT;0;False;13;FLOAT3;0,0,0;False;11;FLOAT3;0,0,0;False;12;FLOAT3;0,0,0;False;14;FLOAT4;0,0,0,0;False;15;FLOAT3;0,0,0;False;0
WireConnection;3;0;2;0
WireConnection;17;0;3;0
WireConnection;17;1;6;0
WireConnection;18;0;8;0
WireConnection;18;1;10;0
WireConnection;12;5;13;0
WireConnection;9;1;8;0
WireConnection;9;0;18;0
WireConnection;4;1;5;0
WireConnection;4;0;1;0
WireConnection;19;0;21;0
WireConnection;19;1;20;0
WireConnection;19;2;11;0
WireConnection;7;1;3;0
WireConnection;7;0;17;0
WireConnection;0;0;4;0
WireConnection;0;1;12;0
WireConnection;0;3;9;0
WireConnection;0;4;7;0
WireConnection;0;5;19;0
ASEEND*/
//CHKSM=B37A3F6B0781B70FC3F3B60C05A5845010EC7A7C
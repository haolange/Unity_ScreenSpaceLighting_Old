Shader "CGBull/Infinity_Shader/ClearCoat" {
    Properties {
        [Header (LUT)]
        [NoScaleOffset]_PreintegratedLUT ("PreintegratedLUT", 2D) = "black" {}

        [Header (Microface)]
        [Toggle (_UseAlbedoTex)]UseBaseColorTex ("UseBaseColorTex", Range(0, 1)) = 0
        [NoScaleOffset]_BaseColorTexture ("BaseColorTexture", 2D) = "gray" {}
        _BaseColorTile ("BaseColorTile", Range(0, 100)) = 1
        _BaseColor ("BaseColor", Color) = (1, 1, 1, 1)

        _SpecularLevel ("SpecularLevel", Range(0, 1)) = 0.5
        _Reflectance ("Reflectance", Range(0, 1)) = 1
        _Roughness ("Roughness", Range(0, 1)) = 0.5



        [Header (Normal)]
        [NoScaleOffset]_NomralTexture ("NomralTexture", 2D) = "bump" {}
        _NormalTile ("NormalTile", Range(0, 100)) = 1



        [Header (ClearCoat)]
        _ClearCoat ("ClearCoat", Range(0, 1)) = 1
        _ClearCoatRoughness ("ClearCoatRoughness", Range(0, 1)) = 0
        [NoScaleOffset]_ClearCoatNomralTexture ("ClearCoatNomralTexture", 2D) = "bump" {}
        _ClearCoatNormalTile ("ClearCoatNormalTile", Range(0, 100)) = 1



        [Header (Iridescence)]

        [Toggle (_Iridescence)] Iridescence ("Iridescence", Range(0, 1)) = 0
        _Iridescence_Distance ("Iridescence_Distance", Range(0, 1)) = 1
    }
    SubShader {
        Tags { "RenderType" = "Opaque" "Queue"="Geometry"}
        LOD 64
        Pass {
            Name "ForwardBase"
            Tags {"LightMode"="ForwardBase"}
                       
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _Iridescence
            #pragma shader_feature _UseAlbedoTex
            
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fwdbase_fullshadows
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
            #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON
            #pragma target 4.5

            #define SHOULD_SAMPLE_SH (defined (LIGHTMAP_OFF) && defined (DYNAMICLIGHTMAP_OFF))

            #include "Assets/ScreenSpaceTechStack/Common/Shaders/Resources/Include_HLSL.hlsl"
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #include "UnityPBSLighting.cginc"

            float _BaseColorTile, _NormalTile, _ClearCoatNormalTile, _Iridescence_Distance, _SpecularLevel, _Roughness, _Reflectance, _ClearCoat, _ClearCoatRoughness;
            float4 _BaseColor, _TransmissionColor;
            sampler2D _PreintegratedLUT, _BaseColorTexture, _NomralTexture, _ClearCoatNomralTexture; 

            struct VertexInput {
                float4 pos : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
            };

            struct PixelInput {
                float4 pos : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                float4 posWorld : TEXCOORD3;
                float4 screenPos : TEXCOORD4;
                float3 normalDir : TEXCOORD5;
                float3 tangentDir : TEXCOORD6;
                float3 bitangentDir : TEXCOORD7;
                LIGHTING_COORDS(8,9)
                #if defined(LIGHTMAP_ON) || defined(UNITY_SHOULD_SAMPLE_SH)
                    float4 ambientOrLightmapUV : TEXCOORD8;
                #endif
            };
            
            PixelInput vert (VertexInput v) {
                PixelInput o = (PixelInput)0;
                o.pos = UnityObjectToClipPos(v.pos);
                o.uv0 = v.uv0;
                o.uv1 = v.uv1;
                o.uv2 = v.uv2;
                o.posWorld = mul(unity_ObjectToWorld, v.pos);
                o.screenPos = ComputeScreenPos(o.pos);
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.tangentDir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0)).xyz);
                o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
                #ifdef LIGHTMAP_ON
                    o.ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                    o.ambientOrLightmapUV.zw = 0;
                #endif
                #ifdef DYNAMICLIGHTMAP_ON
                    o.ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                #endif
                return o;
            }

            float3 frag(PixelInput i) : SV_TARGET {
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float3 worldPos = i.posWorld.xyz;
                float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, normalize(i.normalDir));

////// Lighting Data:
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 halfDir = normalize(viewDir + lightDir);
                float3 nomralDir_Tex = UnpackNormal(tex2D(_NomralTexture, i.uv0 * _NormalTile));
                float3 normalDir = normalize(mul(nomralDir_Tex, tangentTransform)); 
                float3 ReflectDir = reflect(-viewDir, normalDir);      

                BSDFContext BSDFContext;
                Init(BSDFContext, normalDir, viewDir, lightDir, halfDir);

                half3 Attenuation = UnityComputeForwardShadows(i.ambientOrLightmapUV, worldPos, i.screenPos);
                Attenuation *= _LightColor0.rgb * BSDFContext.NoL;

////// Material Property
                #if _UseAlbedoTex
                    half3 BaseColor = tex2D(_BaseColorTexture, i.uv0 * _BaseColorTile).rgb * _BaseColor.rgb;
                #else
                    half3 BaseColor = _BaseColor.rgb;   
                #endif
    
                half3 AlbedoColor = BaseColor * (1 - _Reflectance);
                half Roughness = clamp(_Roughness, 0.04, 1);

                #if _Iridescence
                    half3 Iridescence_Color = Flim_Iridescence(1, BSDFContext.NoV, _Iridescence_Distance, 0.04);
                    half3 SpecularColor = lerp(0.08 * _SpecularLevel, Iridescence_Color, _Reflectance);
                #else
                    half3 SpecularColor = lerp(0.08 * _SpecularLevel, BaseColor, _Reflectance);
                #endif

/////// GI Data:
                UnityGIInput d;
                d.worldPos = worldPos;

                #if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
                    d.ambient = 0;
                    d.lightmapUV = i.ambientOrLightmapUV;
                #else
                    d.ambient = i.ambientOrLightmapUV;
                #endif

                #if UNITY_SPECCUBE_BLENDING || UNITY_SPECCUBE_BOX_PROJECTION
                    d.boxMin[0] = unity_SpecCube0_BoxMin;
                    d.boxMin[1] = unity_SpecCube1_BoxMin;
                #endif

                #if UNITY_SPECCUBE_BOX_PROJECTION
                    d.boxMax[0] = unity_SpecCube0_BoxMax;
                    d.boxMax[1] = unity_SpecCube1_BoxMax;
                    d.probePosition[0] = unity_SpecCube0_ProbePosition;
                    d.probePosition[1] = unity_SpecCube1_ProbePosition;
                #endif

                d.probeHDR[0] = unity_SpecCube0_HDR;
                d.probeHDR[1] = unity_SpecCube1_HDR;
                Unity_GlossyEnvironmentData ugls_en_data;
                ugls_en_data.roughness = Roughness;
                ugls_en_data.reflUVW = ReflectDir;
                UnityGI gi = UnityGlobalIllumination(d, 1, normalDir, ugls_en_data);


//////////////////////ClearCoat Data
                float ClearCoatRoughness = clamp(_ClearCoatRoughness, 0.04, 1);
                float3 ClearCoat_NomralTex = UnpackNormal(tex2D(_ClearCoatNomralTexture, i.uv0 * _ClearCoatNormalTile));
                float3 ClearCoat_NormalDir = normalize(mul(ClearCoat_NomralTex, tangentTransform));
                float3 ClarCoat_ReflectDir = reflect(-viewDir, ClearCoat_NormalDir); 

                UnityGIInput ClearCoat_Data;
                ClearCoat_Data.worldPos = worldPos;

                #if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
                    ClearCoat_Data.ambient = 0;
                    ClearCoat_Data.lightmapUV = i.ambientOrLightmapUV;
                #else
                    ClearCoat_Data.ambient = i.ambientOrLightmapUV;
                #endif

                #if UNITY_SPECCUBE_BLENDING || UNITY_SPECCUBE_BOX_PROJECTION
                    ClearCoat_Data.boxMin[0] = unity_SpecCube0_BoxMin;
                    ClearCoat_Data.boxMin[1] = unity_SpecCube1_BoxMin;
                #endif

                #if UNITY_SPECCUBE_BOX_PROJECTION
                    ClearCoat_Data.boxMax[0] = unity_SpecCube0_BoxMax;
                    ClearCoat_Data.boxMax[1] = unity_SpecCube1_BoxMax;
                    ClearCoat_Data.probePosition[0] = unity_SpecCube0_ProbePosition;
                    ClearCoat_Data.probePosition[1] = unity_SpecCube1_ProbePosition;
                #endif

                ClearCoat_Data.probeHDR[0] = unity_SpecCube0_HDR;
                ClearCoat_Data.probeHDR[1] = unity_SpecCube1_HDR;
                Unity_GlossyEnvironmentData ClearCoat_GlossData;
                ClearCoat_GlossData.roughness = ClearCoatRoughness;
                ClearCoat_GlossData.reflUVW = ClarCoat_ReflectDir;

/////// Final Color
                float ClearCoatIntensity = F_Schlick( 0.05, 1, max( dot (normalize(i.normalDir), viewDir ), 0 ) ) * _ClearCoat;

                half3 ClearCoat_EnergyCompensation;
                float3 ClearCoat_GF = PreintegratedDGF_LUT(_PreintegratedLUT, ClearCoat_EnergyCompensation, 1, ClearCoatRoughness, max(dot(ClearCoat_NormalDir, viewDir), 0)).rgb;
                float3 ClearCoat_Reflection = UnityGI_IndirectSpecular(ClearCoat_Data, 1, ClearCoat_NormalDir, ClearCoat_GlossData) * ClearCoat_GF * ClearCoat_EnergyCompensation;

                half3 EnergyCompensation;
                half4 Preintegrated_DGF = PreintegratedDGF_LUT(_PreintegratedLUT, EnergyCompensation, SpecularColor, Roughness, BSDFContext.NoV);
                float3 GlobalIllumination = (AlbedoColor * gi.indirect.diffuse * Preintegrated_DGF.a) + (lerp(gi.indirect.specular * Preintegrated_DGF.rgb * EnergyCompensation, ClearCoat_Reflection, ClearCoatIntensity));

                float3 ClearCoat_Shading = ClearCoat_Lit(BSDFContext, Attenuation, EnergyCompensation, ClearCoat_EnergyCompensation, AlbedoColor, SpecularColor, _ClearCoat, ClearCoatRoughness, Roughness);

                return ClearCoat_Shading + GlobalIllumination;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}

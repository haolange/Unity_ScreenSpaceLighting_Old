Shader "CGBull/Infinity_Shader/Hair" {
    Properties {
        _Area ("Area", Range(0, 1)) = 1

        _SpecularColor ("SpecularColor", Color) = (0.7, 0.25, 0.1, 1)
        _SpecularIntensity ("SpecularIntensity", Range(0, 1)) = 0

        _Backlit ("Backlit", Range(0, 1)) = 1
        _ScatterIntensity ("ScatterIntensity", Range(0, 1)) = 0.2

        _Roughness ("Roughness", Range(0, 1)) = 0.3
        _NomralTexture ("NomralTexture", 2D) = "bump" {}
        _NormalTile ("NormalTile", Range(0, 100)) = 1
    }
    SubShader {
        Tags { "RenderType" = "Opaque" "Queue"="Geometry"}
        LOD 64
        Pass {
            Name "ForwardBase"
            Tags {"LightMode"="ForwardBase"}
            Cull Off
                       
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fwdbase_fullshadows
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma multi_compile DIRLIGHTMAP_OFF DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE
            #pragma multi_compile DYNAMICLIGHTMAP_OFF DYNAMICLIGHTMAP_ON
            #pragma target 4.5

            #define SHOULD_SAMPLE_SH (defined (LIGHTMAP_OFF) && defined (DYNAMICLIGHTMAP_OFF))

            #include "Assets/TP/CGBull/Common/Shaders/Resources/Include_HLSL.hlsl"
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #include "UnityPBSLighting.cginc"

            float _NormalTile, _SpecularIntensity, _Backlit, _ScatterIntensity, _Area, _Roughness;
            float4 _SpecularColor;
            sampler2D _NomralTexture; 

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

            float4 frag(PixelInput i) : SV_TARGET {
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float3 worldPos = i.posWorld.xyz;
                float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, normalize(i.normalDir));

////// Lighting Data:
                //////CommonData
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 lightColor = _LightColor0.rgb;
                float lightAtten = UnityComputeForwardShadows(i.ambientOrLightmapUV, worldPos, i.screenPos);
                float3 lightAttenColor = lightAtten * _LightColor0.xyz; 
                float3 halfDir = normalize(viewDir + lightDir);
                //////BaseData
                float3 nomralDir_Tex = UnpackNormal(tex2D(_NomralTexture, i.uv0 * _NormalTile));
                float3 normalDir = normalize(mul(nomralDir_Tex, tangentTransform)); 

                float3 viewReflectDir = reflect(-viewDir, normalDir);               
                float NoL = saturate(dot(normalDir, lightDir));
                float LoH = saturate(dot(lightDir, halfDir));
                float NoV = abs(dot(normalDir, viewDir));
                float NoH = saturate(dot(normalDir, halfDir)); 

////// Material Property
                float3 specularColor = _SpecularColor;
                float specularIntensity = _SpecularIntensity;
                float roughness = clamp(_Roughness, 0.04, 1);

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
                ugls_en_data.roughness = roughness;
                ugls_en_data.reflUVW = viewReflectDir;
                UnityGI gi = UnityGlobalIllumination(d, 1, normalDir, ugls_en_data);


                float3 hair_DirectionLighting = Hair_Lit(lightDir, viewDir, normalDir, specularColor, specularIntensity, roughness, _Backlit, _ScatterIntensity, _Area, lightAtten) * lightAttenColor;
                float3 hair_inDirectionLighting = ImageBasedLighting_Hair(viewDir, normalDir, specularColor, roughness, _ScatterIntensity);

/////// Final Color
                float3 hair_Lighting = hair_DirectionLighting + hair_inDirectionLighting;
                return float4(hair_Lighting, 1);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}

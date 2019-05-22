Shader "CGBull/Test/PrefilterIBL" {
    Properties {
        [Header (Microface)]
        [NoScaleOffset]_CubeTexture ("CubeTexture", Cube) = "white" {}
        _Roughness ("Roughness", Range(0, 1)) = 0


        [Header (Normal)]
        [NoScaleOffset]_NomralTexture ("NomralTexture", 2D) = "bump" {}
        _NormalTile ("NormalTile", Range(0, 100)) = 1

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

            float _NormalTile, _Roughness;
            sampler2D _NomralTexture; 
            samplerCUBE _CubeTexture;

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
                float4 ambientOrLightmapUV : TEXCOORD8;
            };
            
            PixelInput vert (VertexInput v) {
                PixelInput o;
                o.pos = UnityObjectToClipPos(v.pos);
                o.uv0 = v.uv0;
                o.uv1 = v.uv1;
                o.uv2 = v.uv2;
                o.posWorld = mul(unity_ObjectToWorld, v.pos);
                o.screenPos = ComputeScreenPos(o.pos);
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.tangentDir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0)).xyz);
                o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
                o.ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                o.ambientOrLightmapUV.zw = 0;
                return o;
            }

            float3 PrefilterEnvMap( samplerCUBE _AmbientCubemap, float Roughness, float3 Position ) {
                float3 N = Position; float3 R = N; float3 V = R;
            
                const uint NumSamples = 32u; float TotalWeight = 0.0; float3 PrefiterColor = 0.0;
                
                for(uint i = 0u; i < NumSamples; ++i) {
                    float2 Xi = Hammersley(i, NumSamples, HaltonSequence(i));
                    float3 H = TangentToWorld( ImportanceSampleGGX(Xi, Roughness), half4(N, 1.0) ).xyz;
                    float3 L  = 2.0 * dot(V, H) * H - V;
            
                    float NdotL = max(dot(N, L), 0.0);
                    if(NdotL > 0.0) {
                        float NoH = max(dot(N, H), 0.0);
                        float HoV = max(dot(H, V), 0.0);

                        float D   = D_GGX(NoH, Roughness);
                        float PDF = D * NoH / (4.0 * HoV) + 0.0001; 
            
                        float Resolution = 64.0;
                        float saTexel  = 4.0 * PI / (6.0 * Resolution * Resolution);
                        float saSample = 1.0 / (float(NumSamples) * PDF + 0.0001);
                
                        float MipLevel = Roughness == 0.0 ? 0.0 : 0.5 * log2(saSample / saTexel); 
                        
                        TotalWeight += NdotL;
                        PrefiterColor += texCUBElod( _AmbientCubemap, half4( L, MipLevel) ).rgb * NdotL;
                    }
                }
                return PrefiterColor / TotalWeight;
            }

            half3 frag(PixelInput i) : SV_TARGET {
                half2 screenUV = i.screenPos.xy / i.screenPos.w;
                half3 worldPos = i.posWorld.xyz;
                half3x3 tangentTransform = half3x3(i.tangentDir, i.bitangentDir, normalize(i.normalDir));

////// Lighting Data:
                half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos);
                half3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                half3 halfDir = normalize(viewDir + lightDir);
                half3 nomralDir_Tex = UnpackNormal(tex2D(_NomralTexture, i.uv0 * _NormalTile));
                half3 normalDir = normalize(mul(nomralDir_Tex, tangentTransform)); 
                half3 ReflectDir = reflect(-viewDir, normalDir);      
                
                half Roughness = clamp(_Roughness, 0.04, 1);
                half3 CubePrefilter = PrefilterEnvMap(_CubeTexture, Roughness, ReflectDir);
                
                return CubePrefilter;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}

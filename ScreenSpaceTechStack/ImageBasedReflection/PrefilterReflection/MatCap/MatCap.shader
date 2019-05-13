Shader "CGBull//Test/MatCap"
{
    Properties {
        _Color ("Main Color", Color) = (1,1,1,1)
        _MainTex("Albedo Tex", 2D) = "white" {}
        _BumpMap ("Normal Tex", 2D) = "bump" {}
        _BumpValue ("Normal Value", Range(0,10)) = 1
        _MatCapDiffuse ("MatCap Diffuse (RGB)", 2D) = "white" {}
        _DiffuseValue ("Diffuse Value", Range(0,5)) = 1
        _MatCapSpec ("MatCap Spec (RGB)", 2D) = "white" {}
        _SpecValue ("Spec Value", Range(0,5)) = 0
        _SpecTex("Spec Tex", 2D) = "white" {}
        _SpecTexValue("Spec Tex Value", Range(0,2)) = 1 
    }

    Subshader {
        Tags { "RenderType"="Opaque" }

        Pass {
            Tags { "LightMode" = "Always" }

            CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #include "UnityCG.cginc"

                struct v2f { 
                    float4 pos : SV_POSITION;
                    float4  uv : TEXCOORD0;
                    float3  TtoV0 : TEXCOORD1;
                    float3  TtoV1 : TEXCOORD2;
                };

                uniform float4 _BumpMap_ST;
                uniform float4 _MainTex_ST;

                v2f vert (appdata_tan v)
                {
                    v2f o;
                    o.pos = UnityObjectToClipPos (v.vertex);
                    o.uv.xy = TRANSFORM_TEX(v.texcoord,_MainTex);
                    o.uv.zw = TRANSFORM_TEX(v.texcoord,_BumpMap);


                    TANGENT_SPACE_ROTATION;
                    o.TtoV0 = normalize(mul(rotation, UNITY_MATRIX_IT_MV[0].xyz));
                    o.TtoV1 = normalize(mul(rotation, UNITY_MATRIX_IT_MV[1].xyz));
                    return o;
                }

                uniform fixed4 _Color;
                uniform sampler2D _BumpMap;
                uniform sampler2D _MatCapDiffuse;
                uniform sampler2D _MainTex;
                uniform sampler2D _MatCapSpec;
                uniform sampler2D _SpecTex;
                uniform fixed _BumpValue;
                uniform fixed _DiffuseValue;
                uniform fixed _SpecValue;
                uniform fixed _SpecTexValue;

                fixed lum(fixed3 col)
                {
                    return col.r * 0.2 + col.g * 0.7 + col.b * 0.1;
                }

                float4 frag (v2f i) : COLOR
                {
                    fixed4 c = tex2D(_MainTex, i.uv.xy);
                    float3 normal = UnpackNormal(tex2D(_BumpMap, i.uv.zw));
                    normal.xy *= _BumpValue;
                    normal.z = sqrt(1.0- saturate(dot(normal.xy ,normal.xy)));
                    normal = normalize(normal);

                    half2 vn;
                    vn.x = dot(i.TtoV0, normal);
                    vn.y = dot(i.TtoV1, normal);

                    vn = vn * 0.5 + 0.5;

                    fixed4 matcapDiffuse = tex2D(_MatCapDiffuse, vn) * _DiffuseValue;   
                    fixed4 specTex = tex2D(_SpecTex, i.uv.xy) * _SpecTexValue;
                    fixed4 matcapSpec = tex2D(_MatCapSpec, vn) * _SpecValue * specTex;
                    fixed4 diffuse = matcapDiffuse * c * _Color;
                    fixed4 finalColor = diffuse + lerp(0, matcapSpec, lum(specTex.rgb));
                    return finalColor;
                }

            ENDCG
        }
    }
}

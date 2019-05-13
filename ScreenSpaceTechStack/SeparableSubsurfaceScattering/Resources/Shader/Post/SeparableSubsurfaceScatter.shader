Shader "Hidden/SeparableSubsurfaceScatter" {
    CGINCLUDE
        #include "SeparableSubsurfaceScatterCommon.cginc"
    ENDCG

    SubShader {
        ZTest Always
        ZWrite Off 
        Cull Off
        Stencil {
            Ref 5
            comp equal
            pass keep
        }
        Pass {
            Name "XBlur"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment XBlur_frag

            float4 XBlur_frag(PixelInput i) : SV_TARGET {
                float4 SceneColor = tex2D(_MainTex, i.uv);
                float SSSIntencity = (_SSSScale * _CameraDepthTexture_TexelSize.x);
                float3 XBlurPlus = SeparableSubsurface(SceneColor, i.uv, float2(SSSIntencity, 0)).rgb;
                float3 XBlurNagteiv = SeparableSubsurface(SceneColor, i.uv, float2(-SSSIntencity, 0)).rgb;
                float3 XBlur = (XBlurPlus + XBlurNagteiv) / 2;
                return float4(XBlur, SceneColor.a);
            }
            ENDCG
        } Pass {
            Name "YBlur"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment YBlur_frag

            float4 YBlur_frag(PixelInput i) : SV_TARGET {
                float4 SceneColor = tex2D(_MainTex, i.uv);
                float SSSIntencity = (_SSSScale * _CameraDepthTexture_TexelSize.y);
                float3 YBlurPlus = SeparableSubsurface(SceneColor, i.uv, float2(0, SSSIntencity)).rgb;
                float3 YBlurNagteiv = SeparableSubsurface(SceneColor, i.uv, float2(0, -SSSIntencity)).rgb;
                float3 YBlur = (YBlurPlus + YBlurNagteiv) / 2;
                return float4(YBlur, SceneColor.a);
            }
            ENDCG
        }
    }
}

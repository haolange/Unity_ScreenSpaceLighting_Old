#include "UnityCG.cginc" 
#define DistanceToProjectionWindow 5.671281819617709             //1.0 / tan(0.5 * radians(20));
#define DPTimes300 1701.384545885313                             //DistanceToProjectionWindow * 300
#define SamplerSteps 25

uniform float _SSSScale;
uniform float4 _Kernel[SamplerSteps], _Jitter, _NoiseSize, _screenSize, _CameraDepthTexture_TexelSize;
uniform sampler2D _MainTex, _CameraDepthTexture, _Noise;

struct VertexInput {
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
};

struct PixelInput {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

PixelInput vert (VertexInput v) {
    PixelInput o;
    o.pos = v.vertex;
    o.uv = v.uv;
    return o;
}

float4 _RandomSeed;
inline int2 ihash(int2 n)
{
	n = (n << 13) ^ n;
	return (n*(n*n * 15731 + 789221) + 1376312589) & 2147483647;
}

inline int3 ihash(int3 n)
{
	n = (n << 13) ^ n;
	return (n*(n*n * 15731 + 789221) + 1376312589) & 2147483647;
}

inline float2 frand(int2 n)
{
	return ihash(n) / 2147483647.0;
}

inline float3 frand(int3 n)
{
	return ihash(n) / 2147483647.0;
}

inline float2 cellNoise(float2 p)
{
	int seed = dot(p, float2(641338.4168541, 963955.16871685));
	return sin(float2(frand(int2(seed, seed - 53))) * _RandomSeed.xy + _RandomSeed.zw);
}

inline float3 cellNoise(float3 p)
{
	int seed = dot(p, float3(641738.4168541, 9646285.16871685, 3186964.168734));
	return sin(float3(frand(int3(seed, seed - 12, seed - 57))) * _RandomSeed.xyz + _RandomSeed.w);
}

float4 SeparableSubsurface(float4 SceneColor, float2 UV, float2 SSSIntencity) {
    float SceneDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UV));                                   
    float BlurLength = DistanceToProjectionWindow / SceneDepth;                                   
    float2 UVOffset = SSSIntencity * BlurLength;     
    //float2 jitter = tex2Dlod(_Noise, float4((UV + _Jitter.zw) * _screenSize.xy / _NoiseSize.xy, 0, -255)).xy; 
    //float2 jitter = cellNoise(UV); 
    //float2x2 rotateMatrix = float2x2(jitter.x, jitter.y, -jitter.y, jitter.x);           
    float4 BlurSceneColor = SceneColor;
    BlurSceneColor.rgb *=  _Kernel[0].rgb;  

    UNITY_LOOP
    for (int i = 1; i < SamplerSteps; i++) {

        //[flatten] if(abs(_Kernel[i].a) < 0.05) UVOffset = mul(UVOffset, rotateMatrix);

        float2 SSSUV = UV + _Kernel[i].a * UVOffset;
        float4 SSSSceneColor = tex2D(_MainTex, SSSUV);
        float SSSDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, SSSUV)).r;         
        float SSSScale = saturate(DPTimes300 * SSSIntencity * abs(SceneDepth - SSSDepth));
        SSSSceneColor.rgb = lerp(SSSSceneColor.rgb, SceneColor.rgb, SSSScale);
        BlurSceneColor.rgb +=  _Kernel[i].rgb * SSSSceneColor.rgb;

    }
    return BlurSceneColor;
}
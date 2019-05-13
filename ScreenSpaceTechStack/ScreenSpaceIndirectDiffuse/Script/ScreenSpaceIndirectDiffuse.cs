using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;


[ExecuteInEditMode]
//[ImageEffectAllowedInSceneView]
[RequireComponent(typeof(Camera))]
public class ScreenSpaceIndirectDiffuse : MonoBehaviour
{
    private enum RenderResolution
    {
        Full = 1,
        Half = 2
    };

    private enum DebugPass
    {
        Combine = 5,
        IndirectColor = 6
    };

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    [Header("Common Property")]

    [SerializeField]
    RenderResolution RayCastingResolution = RenderResolution.Full;


    [Range(1, 16)]
    [SerializeField]
    int RayNums = 3;


    [Range(0.05f, 5)]
    [SerializeField]
    float Thickness = 0.05f;


    [Range(0, 0.5f)]
    [SerializeField]
    float ScreenFade = 0.05f;



    [Header("Trace Property")]

    [SerializeField]
    bool RayMask = true;


    [Range(32, 512)]
    [SerializeField]
    int HiZ_RaySteps = 38;


    [Range(4, 10)]
    [SerializeField]
    int HiZ_MaxLevel = 10;


    [Range(0, 2)]
    [SerializeField]
    int HiZ_StartLevel = 1;


    [Range(0, 2)]
    [SerializeField]
    int HiZ_StopLevel = 0;



    [Header("Filtter Property")]

    [SerializeField]
    Texture2D BlueNoise_LUT = null;


    [Range(1, 128)]
    [SerializeField]
    float Gi_Intensity = 1;


    [Range(0, 0.99f)]
    [SerializeField]
    float TemporalWeight = 0.99f;


    [Range(1, 5)]
    [SerializeField]
    float TemporalScale = 1.25f;



    [Header("DeBug Property")]

    [SerializeField]
    bool Denoise = true;


    [SerializeField]
    bool RunTimeDebugMod = true;


    [SerializeField]
    DebugPass DeBugPass = DebugPass.IndirectColor;


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    private static int RenderPass_HiZ_Depth = 0;
    private static int RenderPass_HiZ3D_MultiSpp = 1;
    private static int RenderPass_Temporalfilter = 2;
    private static int RenderPass_Bilateralfilter_X = 3;
    private static int RenderPass_Bilateralfilter_Y = 4;

    private Camera RenderCamera;
    private CommandBuffer SSGi_Buffer = null;
    private Material SSGi_Material;

    private Vector2 RandomSampler = new Vector2(1, 1);
    private Vector2 CameraSize;
    private Matrix4x4 SSGi_ProjectionMatrix;
    private Matrix4x4 SSGi_ViewProjectionMatrix;
    private Matrix4x4 SSGi_Prev_ViewProjectionMatrix;
    private Matrix4x4 SSGi_WorldToCameraMatrix;
    private Matrix4x4 SSGi_CameraToWorldMatrix;



    private RenderTexture SSGi_TraceMask_RT, SSGi_TemporalPrev_RT, SSGi_TemporalCurr_RT, SSGi_Bilateral_RT, SSGi_CombineScene_RT, SSGi_HierarchicalDepth_RT, SSGi_HierarchicalDepth_BackUp_RT, SSGi_SceneColor_RT;



    private static int SSGi_Jitter_ID = Shader.PropertyToID("_SSGi_Jitter");
    private static int SSGi_GiIntensity_ID = Shader.PropertyToID("_SSGi_GiIntensity");
    private static int SSGi_MaskRay_ID = Shader.PropertyToID("_SSGi_MaskRay");
    private static int SSGi_NumSteps_HiZ_ID = Shader.PropertyToID("_SSGi_NumSteps_HiZ");
    private static int SSGi_NumRays_ID = Shader.PropertyToID("_SSGi_NumRays");
    private static int SSGi_ScreenFade_ID = Shader.PropertyToID("_SSGi_ScreenFade");
    private static int SSGi_Thickness_ID = Shader.PropertyToID("_SSGi_Thickness");
    private static int SSGi_TemporalScale_ID = Shader.PropertyToID("_SSGi_TemporalScale");
    private static int SSGi_TemporalWeight_ID = Shader.PropertyToID("_SSGi_TemporalWeight");
    private static int SSGi_ScreenSize_ID = Shader.PropertyToID("_SSGi_ScreenSize");
    private static int SSGi_RayCastSize_ID = Shader.PropertyToID("_SSGi_RayCastSize");
    private static int SSGi_NoiseSize_ID = Shader.PropertyToID("_SSGi_NoiseSize");
    private static int SSGi_HiZ_PrevDepthLevel_ID = Shader.PropertyToID("_SSGi_HiZ_PrevDepthLevel");
    private static int SSGi_HiZ_MaxLevel_ID = Shader.PropertyToID("_SSGi_HiZ_MaxLevel");
    private static int SSGi_HiZ_StartLevel_ID = Shader.PropertyToID("_SSGi_HiZ_StartLevel");
    private static int SSGi_HiZ_StopLevel_ID = Shader.PropertyToID("_SSGi_HiZ_StopLevel");



    private static int SSGi_Noise_ID = Shader.PropertyToID("_SSGi_Noise");
    private static int SSGi_HierarchicalDepth_ID = Shader.PropertyToID("_SSGi_HierarchicalDepth_RT");
    private static int SSGi_SceneColor_ID = Shader.PropertyToID("_SSGi_SceneColor_RT");
    private static int SSGi_CombineScene_ID = Shader.PropertyToID("_SSGi_CombienReflection_RT");



    private static int SSGi_Trace_ID = Shader.PropertyToID("_SSGi_RayCastRT");
    private static int SSGi_TemporalPrev_ID = Shader.PropertyToID("_SSGi_TemporalPrev_RT");
    private static int SSGi_TemporalCurr_ID = Shader.PropertyToID("_SSGi_TemporalCurr_RT");
    private static int SSGi_Bilateral_ID = Shader.PropertyToID("_SSGi_Bilateral_RT");



    private static int SSGi_ProjectionMatrix_ID = Shader.PropertyToID("_SSGi_ProjectionMatrix");
    private static int SSGi_ViewProjectionMatrix_ID = Shader.PropertyToID("_SSGi_ViewProjectionMatrix");
    private static int SSGi_LastFrameViewProjectionMatrix_ID = Shader.PropertyToID("_SSGi_LastFrameViewProjectionMatrix");
    private static int SSGi_InverseProjectionMatrix_ID = Shader.PropertyToID("_SSGi_InverseProjectionMatrix");
    private static int SSGi_InverseViewProjectionMatrix_ID = Shader.PropertyToID("_SSGi_InverseViewProjectionMatrix");
    private static int SSGi_WorldToCameraMatrix_ID = Shader.PropertyToID("_SSGi_WorldToCameraMatrix");
    private static int SSGi_CameraToWorldMatrix_ID = Shader.PropertyToID("_SSGi_CameraToWorldMatrix");
    private static int SSGi_ProjectToPixelMatrix_ID = Shader.PropertyToID("_SSGi_ProjectToPixelMatrix");

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    void Awake()
    {
        RenderCamera = gameObject.GetComponent<Camera>();
        SSGi_Material = new Material(Shader.Find("Hidden/ScreenSpaceGlobalillumination"));

        //////Install RenderBuffer//////
        if (SSGi_Buffer == null) 
        {
            SSGi_Buffer = new CommandBuffer();
            SSGi_Buffer.name = "ScreenSpaceGlobalillumination";
        }

        //////Update don't need Tick Refresh Variable//////
        SSR_UpdateVariable();
    }

    void OnEnable()
    {
        if (SSGi_Buffer != null) {
            RenderCamera.AddCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, SSGi_Buffer);
        }
    }

    void OnPreRender()
    {
        RandomSampler = GenerateRandomOffset();
        SSR_UpdateVariable();

        if (SSGi_Buffer != null)
        {
            RenderScreenSpaceIndirectDiffuse();
        }
    }

    void OnDisable()
    {
        if (SSGi_Buffer != null) {
            RenderCamera.RemoveCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, SSGi_Buffer);
        }
    }

    void OnDestroy()  
    {
        ReleaseSSRBuffer();
    }


////////////////////////////////////////////////////////////////SSR Function////////////////////////////////////////////////////////////////
    private int m_SampleIndex = 0;
    private const int k_SampleCount = 64;
    private float GetHaltonValue(int index, int radix)
    {
        float result = 0f;
        float fraction = 1f / radix;

        while (index > 0)
        {
            result += (index % radix) * fraction;
            index /= radix;
            fraction /= radix;
        }
        return result;
    }
    private Vector2 GenerateRandomOffset()
    {
        var offset = new Vector2(GetHaltonValue(m_SampleIndex & 1023, 2), GetHaltonValue(m_SampleIndex & 1023, 3));
        if (m_SampleIndex++ >= k_SampleCount)
            m_SampleIndex = 0;
        return offset;
    }


    private void SSR_UpdateUniformVariable() {
        SSGi_Material.SetTexture(SSGi_Noise_ID, BlueNoise_LUT);
        SSGi_Material.SetVector(SSGi_ScreenSize_ID, CameraSize);
        SSGi_Material.SetVector(SSGi_RayCastSize_ID, CameraSize / (int)RayCastingResolution);
        SSGi_Material.SetVector(SSGi_NoiseSize_ID, new Vector2(1024, 1024));
        SSGi_Material.SetFloat(SSGi_ScreenFade_ID, ScreenFade);
        SSGi_Material.SetFloat(SSGi_Thickness_ID, Thickness);
        SSGi_Material.SetFloat(SSGi_GiIntensity_ID, Gi_Intensity);
        SSGi_Material.SetInt(SSGi_MaskRay_ID, RayMask ? 1 : 0);
        SSGi_Material.SetInt(SSGi_NumSteps_HiZ_ID, HiZ_RaySteps);
        SSGi_Material.SetInt(SSGi_NumRays_ID, RayNums);
        SSGi_Material.SetInt(SSGi_HiZ_MaxLevel_ID, HiZ_MaxLevel); 
        SSGi_Material.SetInt(SSGi_HiZ_StartLevel_ID, HiZ_StartLevel);
        SSGi_Material.SetInt(SSGi_HiZ_StopLevel_ID, HiZ_StopLevel); 
        SSGi_Material.SetFloat(SSGi_TemporalScale_ID, TemporalScale);
        SSGi_Material.SetFloat(SSGi_TemporalWeight_ID, TemporalWeight);
    }


    private void SSR_UpdateVariable() {
        Vector2 HalfCameraSize = new Vector2(CameraSize.x / 2, CameraSize.y / 2);
        Vector2 CurrentCameraSize = new Vector2(RenderCamera.pixelWidth, RenderCamera.pixelHeight);

        if (CameraSize != CurrentCameraSize)  {
            CameraSize = CurrentCameraSize;

            ////////////SceneColor and HierarchicalDepth RT
            RenderTexture.ReleaseTemporary(SSGi_HierarchicalDepth_RT);
            SSGi_HierarchicalDepth_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.RHalf, RenderTextureReadWrite.Linear); 
            SSGi_HierarchicalDepth_RT.filterMode = FilterMode.Point;
            SSGi_HierarchicalDepth_RT.useMipMap = true;
            SSGi_HierarchicalDepth_RT.autoGenerateMips = true;

            RenderTexture.ReleaseTemporary(SSGi_HierarchicalDepth_BackUp_RT);
            SSGi_HierarchicalDepth_BackUp_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.RHalf, RenderTextureReadWrite.Linear); 
            SSGi_HierarchicalDepth_BackUp_RT.filterMode = FilterMode.Point;
            SSGi_HierarchicalDepth_BackUp_RT.useMipMap = true;
            SSGi_HierarchicalDepth_BackUp_RT.autoGenerateMips = false;



            RenderTexture.ReleaseTemporary(SSGi_SceneColor_RT);
            SSGi_SceneColor_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.DefaultHDR);

            /////////////RayMarching and RayMask RT
            RenderTexture.ReleaseTemporary(SSGi_TraceMask_RT);
            SSGi_TraceMask_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth / (int)RayCastingResolution, RenderCamera.pixelHeight / (int)RayCastingResolution, 0, RenderTextureFormat.ARGBHalf);
            SSGi_TraceMask_RT.filterMode = FilterMode.Point;

            ////////////Temporal RT_01
            RenderTexture.ReleaseTemporary(SSGi_TemporalPrev_RT);
            SSGi_TemporalPrev_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.ARGBHalf); 
            SSGi_TemporalPrev_RT.filterMode = FilterMode.Bilinear;
            RenderTexture.ReleaseTemporary(SSGi_TemporalCurr_RT);
            SSGi_TemporalCurr_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.ARGBHalf); 
            SSGi_TemporalCurr_RT.filterMode = FilterMode.Bilinear;
            ////////////Bilateral RT_01
            RenderTexture.ReleaseTemporary(SSGi_Bilateral_RT);
            SSGi_Bilateral_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.ARGBHalf); 
            SSGi_Bilateral_RT.filterMode = FilterMode.Bilinear;

            ////////////Combine RT
            RenderTexture.ReleaseTemporary(SSGi_CombineScene_RT);
            SSGi_CombineScene_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.DefaultHDR); 
            SSGi_CombineScene_RT.filterMode = FilterMode.Point;

            ////////////Update Uniform Variable
            SSR_UpdateUniformVariable();
        }

        ////////////Set Matrix
#if UNITY_EDITOR
        if (RunTimeDebugMod) {
            SSR_UpdateUniformVariable();
        }
#endif

        SSGi_Material.SetVector(SSGi_Jitter_ID, new Vector4((float)CameraSize.x / 1024, (float)CameraSize.y / 1024, RandomSampler.x, RandomSampler.y));
        SSGi_WorldToCameraMatrix = RenderCamera.worldToCameraMatrix;
        SSGi_CameraToWorldMatrix = SSGi_WorldToCameraMatrix.inverse;
        SSGi_ProjectionMatrix = GL.GetGPUProjectionMatrix(RenderCamera.projectionMatrix, false);
        SSGi_ViewProjectionMatrix = SSGi_ProjectionMatrix * SSGi_WorldToCameraMatrix;
        SSGi_Material.SetMatrix(SSGi_ProjectionMatrix_ID, SSGi_ProjectionMatrix);
        SSGi_Material.SetMatrix(SSGi_ViewProjectionMatrix_ID, SSGi_ViewProjectionMatrix);
        SSGi_Material.SetMatrix(SSGi_InverseProjectionMatrix_ID, SSGi_ProjectionMatrix.inverse);
        SSGi_Material.SetMatrix(SSGi_InverseViewProjectionMatrix_ID, SSGi_ViewProjectionMatrix.inverse);
        SSGi_Material.SetMatrix(SSGi_WorldToCameraMatrix_ID, SSGi_WorldToCameraMatrix);
        SSGi_Material.SetMatrix(SSGi_CameraToWorldMatrix_ID, SSGi_CameraToWorldMatrix);
        SSGi_Material.SetMatrix(SSGi_LastFrameViewProjectionMatrix_ID, SSGi_Prev_ViewProjectionMatrix);

        Matrix4x4 warpToScreenSpaceMatrix = Matrix4x4.identity;
        warpToScreenSpaceMatrix.m00 = HalfCameraSize.x; warpToScreenSpaceMatrix.m03 = HalfCameraSize.x;
        warpToScreenSpaceMatrix.m11 = HalfCameraSize.y; warpToScreenSpaceMatrix.m13 = HalfCameraSize.y;

        Matrix4x4 SSGi_ProjectToPixelMatrix = warpToScreenSpaceMatrix * SSGi_ProjectionMatrix;
        SSGi_Material.SetMatrix(SSGi_ProjectToPixelMatrix_ID, SSGi_ProjectToPixelMatrix);
    }


    private void RenderScreenSpaceIndirectDiffuse() {
        SSGi_Buffer.Clear();

        //////Set HierarchicalDepthRT//////
        SSGi_Buffer.Blit(BuiltinRenderTextureType.ResolvedDepth, SSGi_HierarchicalDepth_RT);
        for (int i = 1; i < HiZ_MaxLevel; ++i)
        {
            SSGi_Buffer.SetGlobalInt(SSGi_HiZ_PrevDepthLevel_ID, i - 1);
            SSGi_Buffer.SetRenderTarget(SSGi_HierarchicalDepth_BackUp_RT, i);
            SSGi_Buffer.DrawMesh(GraphicsUtility.mesh, Matrix4x4.identity, SSGi_Material, 0, RenderPass_HiZ_Depth);
            SSGi_Buffer.CopyTexture(SSGi_HierarchicalDepth_BackUp_RT, 0, i, SSGi_HierarchicalDepth_RT, 0, i);
        }
        SSGi_Buffer.SetGlobalTexture(SSGi_HierarchicalDepth_ID, SSGi_HierarchicalDepth_RT);


        //////Set SceneColorRT//////
        SSGi_Buffer.SetGlobalTexture(SSGi_SceneColor_ID, SSGi_SceneColor_RT);
        SSGi_Buffer.CopyTexture(BuiltinRenderTextureType.CameraTarget, SSGi_SceneColor_RT);


        //////RayCasting//////
        SSGi_Buffer.SetGlobalTexture(SSGi_Trace_ID, SSGi_TraceMask_RT);
        SSGi_Buffer.BlitSRT(SSGi_TraceMask_RT, SSGi_Material, RenderPass_HiZ3D_MultiSpp);

        if (Denoise) {
            //////Temporal filter//////
            SSGi_Buffer.SetGlobalTexture(SSGi_TemporalCurr_ID, SSGi_TemporalCurr_RT);
            SSGi_Buffer.BlitSRT(SSGi_TemporalCurr_RT, SSGi_Material, RenderPass_Temporalfilter);
            SSGi_Buffer.SetGlobalTexture(SSGi_TemporalPrev_ID, SSGi_TemporalPrev_RT);
            SSGi_Buffer.CopyTexture(SSGi_TemporalCurr_RT, SSGi_TemporalPrev_RT);

            //////Bilateral filter//////  
            SSGi_Buffer.SetGlobalTexture(SSGi_Bilateral_ID, SSGi_Bilateral_RT);
            ///XBlur
            SSGi_Buffer.BlitSRT(SSGi_Bilateral_RT, SSGi_Material, RenderPass_Bilateralfilter_X);
            SSGi_Buffer.CopyTexture(SSGi_Bilateral_RT, SSGi_TemporalPrev_RT);
            ///YBlur
            SSGi_Buffer.BlitSRT(SSGi_Bilateral_RT, SSGi_Material, RenderPass_Bilateralfilter_Y);
            SSGi_Buffer.CopyTexture(SSGi_Bilateral_RT, SSGi_TemporalPrev_RT);
            
        } else {
            SSGi_Buffer.SetGlobalTexture(SSGi_Bilateral_ID, SSGi_Bilateral_RT);
            if(RayCastingResolution == RenderResolution.Full) {
                SSGi_Buffer.CopyTexture(SSGi_TraceMask_RT, SSGi_Bilateral_RT);
            } else {
                SSGi_Buffer.Blit(SSGi_TraceMask_RT, SSGi_Bilateral_RT);
            }
        }


        //////Combien IndirectDiffuse//////
        SSGi_Buffer.SetGlobalTexture(SSGi_CombineScene_ID, SSGi_CombineScene_RT);
        #if UNITY_EDITOR
            SSGi_Buffer.BlitSRT(SSGi_CombineScene_RT, BuiltinRenderTextureType.CameraTarget, SSGi_Material, (int)DeBugPass);
        #else
            SSGi_Buffer.BlitSRT(SSGi_CombineScene_RT, BuiltinRenderTextureType.CameraTarget, SSGi_Material, 5);
        #endif

        //////Set Last Frame ViewProjection//////
        SSGi_Prev_ViewProjectionMatrix = SSGi_ViewProjectionMatrix;
    }


    private void ReleaseSSRBuffer() {
        RenderTexture.ReleaseTemporary(SSGi_HierarchicalDepth_RT);
        RenderTexture.ReleaseTemporary(SSGi_SceneColor_RT);
        RenderTexture.ReleaseTemporary(SSGi_TraceMask_RT);
        RenderTexture.ReleaseTemporary(SSGi_TemporalPrev_RT);
        RenderTexture.ReleaseTemporary(SSGi_TemporalCurr_RT);
        RenderTexture.ReleaseTemporary(SSGi_Bilateral_RT);
        RenderTexture.ReleaseTemporary(SSGi_CombineScene_RT);

        if (SSGi_Buffer != null) {
            SSGi_Buffer.Dispose();
        }
    }

}

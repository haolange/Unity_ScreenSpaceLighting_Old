using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;


[ExecuteInEditMode]
[ImageEffectAllowedInSceneView]
[RequireComponent(typeof(Camera))]
public class StochasticScreenSpaceReflection : MonoBehaviour
{
    private enum RenderResolution
    {
        Full = 1,
        Half = 2
    };

    private enum DebugPass
    {
        Combine = 9,
        SSRColor = 10
    };

    private enum TraceApprox
    {
        HiZTrace = 0,
        LinearTrace = 1
    };


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    [Header("Common Property")]

    [SerializeField]
    TraceApprox TraceMethod = TraceApprox.HiZTrace;


    [SerializeField]
    RenderResolution RayCastingResolution = RenderResolution.Full;


    [Range(1, 4)]
    [SerializeField]
    int RayNums = 1;


    [Range(0, 1)]
    [SerializeField]
    float BRDFBias = 0.7f;


    [Range(0.05f, 5)]
    [SerializeField]
    float Thickness = 0.1f;


    [Range(0, 0.5f)]
    [SerializeField]
    float ScreenFade = 0.1f;



    [Header("HiZ_Trace Property")]

    [Range(32, 512)]
    [SerializeField]
    int HiZ_RaySteps = 58;


    [Range(4, 10)]
    [SerializeField]
    int HiZ_MaxLevel = 10;


    [Range(0, 2)]
    [SerializeField]
    int HiZ_StartLevel = 1;


    [Range(0, 2)]
    [SerializeField]
    int HiZ_StopLevel = 0;

    

    [Header("Linear_Trace Property")]

    [SerializeField]
    bool Linear_TraceBehind = false;

    
    [SerializeField]
    bool Linear_TowardRay = true;


    //[Range(64, 512)]
    //[SerializeField]
    int Linear_RayDistance = 512;


    [Range(64, 512)]
    [SerializeField]
    int Linear_RaySteps = 256;


    [Range(5, 20)]
    [SerializeField]
    int Linear_StepSize = 10;



    [Header("Filtter Property")]

    [SerializeField]
    Texture2D BlueNoise_LUT = null;


    [SerializeField]
    Texture PreintegratedGF_LUT = null;


    [Range(1, 9)]
    [SerializeField]
    int SpatioSampler = 9;


    [Range(0, 0.99f)]
    [SerializeField]
    float TemporalWeight = 0.98f;


    [Range(1, 5)]
    [SerializeField]
    float TemporalScale = 1.25f;



    [Header("DeBug Property")]

    [SerializeField]
    bool Denoise = true;
    

    [SerializeField]
    bool RunTimeDebugMod = true;


    [SerializeField]
    DebugPass DeBugPass = DebugPass.SSRColor;


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    private static int RenderPass_HiZ_Depth = 0;
    private static int RenderPass_Linear2D_SingelSPP = 1;
    private static int RenderPass_HiZ3D_SingelSpp = 2;
    private static int RenderPass_Linear2D_MultiSPP = 3;
    private static int RenderPass_HiZ3D_MultiSpp = 4;
    private static int RenderPass_Spatiofilter_SingleSPP = 5;
    private static int RenderPass_Spatiofilter_MultiSPP = 6;
    private static int RenderPass_Temporalfilter_SingleSPP = 7;
    private static int RenderPass_Temporalfilter_MultiSpp = 8;

    private Camera RenderCamera;
    private CommandBuffer ScreenSpaceReflectionBuffer = null;
    private Material StochasticScreenSpaceReflectionMaterial;

    private Vector2 RandomSampler = new Vector2(1, 1);
    private Vector2 CameraSize;
    private Matrix4x4 SSR_ProjectionMatrix;
    private Matrix4x4 SSR_ViewProjectionMatrix;
    private Matrix4x4 SSR_Prev_ViewProjectionMatrix;
    private Matrix4x4 SSR_WorldToCameraMatrix;
    private Matrix4x4 SSR_CameraToWorldMatrix;



    private RenderTexture[] SSR_TraceMask_RT = new RenderTexture[2];  private RenderTargetIdentifier[] SSR_TraceMask_ID = new RenderTargetIdentifier[2];
    private RenderTexture SSR_Spatial_RT, SSR_TemporalPrev_RT, SSR_TemporalCurr_RT, SSR_CombineScene_RT, SSR_HierarchicalDepth_RT, SSR_HierarchicalDepth_BackUp_RT, SSR_SceneColor_RT;



    private static int SSR_Jitter_ID = Shader.PropertyToID("_SSR_Jitter");
    private static int SSR_BRDFBias_ID = Shader.PropertyToID("_SSR_BRDFBias");
    private static int SSR_NumSteps_Linear_ID = Shader.PropertyToID("_SSR_NumSteps_Linear");
    private static int SSR_NumSteps_HiZ_ID = Shader.PropertyToID("_SSR_NumSteps_HiZ");
    private static int SSR_NumRays_ID = Shader.PropertyToID("_SSR_NumRays");
    private static int SSR_NumResolver_ID = Shader.PropertyToID("_SSR_NumResolver");
    private static int SSR_ScreenFade_ID = Shader.PropertyToID("_SSR_ScreenFade");
    private static int SSR_Thickness_ID = Shader.PropertyToID("_SSR_Thickness");
    private static int SSR_TemporalScale_ID = Shader.PropertyToID("_SSR_TemporalScale");
    private static int SSR_TemporalWeight_ID = Shader.PropertyToID("_SSR_TemporalWeight");
    private static int SSR_ScreenSize_ID = Shader.PropertyToID("_SSR_ScreenSize");
    private static int SSR_RayCastSize_ID = Shader.PropertyToID("_SSR_RayCastSize");
    private static int SSR_NoiseSize_ID = Shader.PropertyToID("_SSR_NoiseSize");
    private static int SSR_RayStepSize_ID = Shader.PropertyToID("_SSR_RayStepSize");
    private static int SSR_ProjInfo_ID = Shader.PropertyToID("_SSR_ProjInfo");
    private static int SSR_CameraClipInfo_ID = Shader.PropertyToID("_SSR_CameraClipInfo");
    private static int SSR_TraceDistance_ID = Shader.PropertyToID("_SSR_TraceDistance");
    private static int SSR_BackwardsRay_ID = Shader.PropertyToID("_SSR_BackwardsRay");
    private static int SSR_TraceBehind_ID = Shader.PropertyToID("_SSR_TraceBehind");
    private static int SSR_CullBack_ID = Shader.PropertyToID("_SSR_CullBack");
    private static int SSR_HiZ_PrevDepthLevel_ID = Shader.PropertyToID("_SSR_HiZ_PrevDepthLevel");
    private static int SSR_HiZ_MaxLevel_ID = Shader.PropertyToID("_SSR_HiZ_MaxLevel");
    private static int SSR_HiZ_StartLevel_ID = Shader.PropertyToID("_SSR_HiZ_StartLevel");
    private static int SSR_HiZ_StopLevel_ID = Shader.PropertyToID("_SSR_HiZ_StopLevel");



    private static int SSR_Noise_ID = Shader.PropertyToID("_SSR_Noise");
    private static int SSR_PreintegratedGF_LUT_ID = Shader.PropertyToID("_SSR_PreintegratedGF_LUT");

    private static int SSR_HierarchicalDepth_ID = Shader.PropertyToID("_SSR_HierarchicalDepth_RT");
    private static int SSR_SceneColor_ID = Shader.PropertyToID("_SSR_SceneColor_RT");
    private static int SSR_CombineScene_ID = Shader.PropertyToID("_SSR_CombienReflection_RT");



    private static int SSR_Trace_ID = Shader.PropertyToID("_SSR_RayCastRT");
    private static int SSR_Mask_ID = Shader.PropertyToID("_SSR_RayMask_RT");
    private static int SSR_Spatial_ID = Shader.PropertyToID("_SSR_Spatial_RT");
    private static int SSR_TemporalPrev_ID = Shader.PropertyToID("_SSR_TemporalPrev_RT");
    private static int SSR_TemporalCurr_ID = Shader.PropertyToID("_SSR_TemporalCurr_RT");



    private static int SSR_ProjectionMatrix_ID = Shader.PropertyToID("_SSR_ProjectionMatrix");
    private static int SSR_ViewProjectionMatrix_ID = Shader.PropertyToID("_SSR_ViewProjectionMatrix");
    private static int SSR_LastFrameViewProjectionMatrix_ID = Shader.PropertyToID("_SSR_LastFrameViewProjectionMatrix");
    private static int SSR_InverseProjectionMatrix_ID = Shader.PropertyToID("_SSR_InverseProjectionMatrix");
    private static int SSR_InverseViewProjectionMatrix_ID = Shader.PropertyToID("_SSR_InverseViewProjectionMatrix");
    private static int SSR_WorldToCameraMatrix_ID = Shader.PropertyToID("_SSR_WorldToCameraMatrix");
    private static int SSR_CameraToWorldMatrix_ID = Shader.PropertyToID("_SSR_CameraToWorldMatrix");
    private static int SSR_ProjectToPixelMatrix_ID = Shader.PropertyToID("_SSR_ProjectToPixelMatrix");

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    void Awake()
    {
        RenderCamera = gameObject.GetComponent<Camera>();
        StochasticScreenSpaceReflectionMaterial = new Material(Shader.Find("Hidden/StochasticScreenSpaceReflection"));

        //////Install RenderBuffer//////
        if (ScreenSpaceReflectionBuffer == null) 
        {
            ScreenSpaceReflectionBuffer = new CommandBuffer();
            ScreenSpaceReflectionBuffer.name = "StochasticScreenSpaceReflection";
        }

        //////Update don't need Tick Refresh Variable//////
        SSR_UpdateVariable();
    }

    void OnEnable()
    {
        if (ScreenSpaceReflectionBuffer != null) {
            RenderCamera.AddCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, ScreenSpaceReflectionBuffer);
        }
    }

    void OnPreRender()
    {
        RandomSampler = GenerateRandomOffset();
        SSR_UpdateVariable();

        if (ScreenSpaceReflectionBuffer != null)
        {
            RenderScreenSpaceReflection();
        }
    }

    void OnDisable()
    {
        if (ScreenSpaceReflectionBuffer != null) {
            RenderCamera.RemoveCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, ScreenSpaceReflectionBuffer);
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
        StochasticScreenSpaceReflectionMaterial.SetTexture(SSR_PreintegratedGF_LUT_ID, PreintegratedGF_LUT);
        StochasticScreenSpaceReflectionMaterial.SetTexture(SSR_Noise_ID, BlueNoise_LUT);
        StochasticScreenSpaceReflectionMaterial.SetVector(SSR_ScreenSize_ID, CameraSize);
        StochasticScreenSpaceReflectionMaterial.SetVector(SSR_RayCastSize_ID, CameraSize / (int)RayCastingResolution);
        StochasticScreenSpaceReflectionMaterial.SetVector(SSR_NoiseSize_ID, new Vector2(1024, 1024));
        StochasticScreenSpaceReflectionMaterial.SetFloat(SSR_BRDFBias_ID, BRDFBias);
        StochasticScreenSpaceReflectionMaterial.SetFloat(SSR_ScreenFade_ID, ScreenFade);
        StochasticScreenSpaceReflectionMaterial.SetFloat(SSR_Thickness_ID, Thickness);
        StochasticScreenSpaceReflectionMaterial.SetInt(SSR_RayStepSize_ID, Linear_StepSize);
        StochasticScreenSpaceReflectionMaterial.SetInt(SSR_TraceDistance_ID, Linear_RayDistance);
        StochasticScreenSpaceReflectionMaterial.SetInt(SSR_NumSteps_Linear_ID, Linear_RaySteps);
        StochasticScreenSpaceReflectionMaterial.SetInt(SSR_NumSteps_HiZ_ID, HiZ_RaySteps);
        StochasticScreenSpaceReflectionMaterial.SetInt(SSR_NumRays_ID, RayNums);
        StochasticScreenSpaceReflectionMaterial.SetInt(SSR_BackwardsRay_ID, Linear_TowardRay ? 1 : 0);
        StochasticScreenSpaceReflectionMaterial.SetInt(SSR_CullBack_ID, Linear_TowardRay ? 1 : 0);
        StochasticScreenSpaceReflectionMaterial.SetInt(SSR_TraceBehind_ID, Linear_TraceBehind ? 1 : 0);
        StochasticScreenSpaceReflectionMaterial.SetInt(SSR_HiZ_MaxLevel_ID, HiZ_MaxLevel); 
        StochasticScreenSpaceReflectionMaterial.SetInt(SSR_HiZ_StartLevel_ID, HiZ_StartLevel);
        StochasticScreenSpaceReflectionMaterial.SetInt(SSR_HiZ_StopLevel_ID, HiZ_StopLevel); 
        if (Denoise) {
            StochasticScreenSpaceReflectionMaterial.SetInt(SSR_NumResolver_ID, SpatioSampler);
            StochasticScreenSpaceReflectionMaterial.SetFloat(SSR_TemporalScale_ID, TemporalScale);
            StochasticScreenSpaceReflectionMaterial.SetFloat(SSR_TemporalWeight_ID, TemporalWeight);
        } else {
            StochasticScreenSpaceReflectionMaterial.SetInt(SSR_NumResolver_ID, 1);
            StochasticScreenSpaceReflectionMaterial.SetFloat(SSR_TemporalScale_ID, 0);
            StochasticScreenSpaceReflectionMaterial.SetFloat(SSR_TemporalWeight_ID, 0);
        }
    }



    private void SSR_UpdateVariable() {
        Vector2 HalfCameraSize = new Vector2(CameraSize.x / 2, CameraSize.y / 2);
        Vector2 CurrentCameraSize = new Vector2(RenderCamera.pixelWidth, RenderCamera.pixelHeight);

        if (CameraSize != CurrentCameraSize)  {
            CameraSize = CurrentCameraSize;

            ////////////SceneColor and HierarchicalDepth RT
            RenderTexture.ReleaseTemporary(SSR_HierarchicalDepth_RT);
            SSR_HierarchicalDepth_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.RHalf, RenderTextureReadWrite.Linear); 
            SSR_HierarchicalDepth_RT.filterMode = FilterMode.Point;
            SSR_HierarchicalDepth_RT.useMipMap = true;
            SSR_HierarchicalDepth_RT.autoGenerateMips = true;

            RenderTexture.ReleaseTemporary(SSR_HierarchicalDepth_BackUp_RT);
            SSR_HierarchicalDepth_BackUp_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.RHalf, RenderTextureReadWrite.Linear); 
            SSR_HierarchicalDepth_BackUp_RT.filterMode = FilterMode.Point;
            SSR_HierarchicalDepth_BackUp_RT.useMipMap = true;
            SSR_HierarchicalDepth_BackUp_RT.autoGenerateMips = false;



            RenderTexture.ReleaseTemporary(SSR_SceneColor_RT);
            SSR_SceneColor_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.DefaultHDR);

            /////////////RayMarching and RayMask RT
            RenderTexture.ReleaseTemporary(SSR_TraceMask_RT[0]);
            SSR_TraceMask_RT[0] = RenderTexture.GetTemporary(RenderCamera.pixelWidth / (int)RayCastingResolution, RenderCamera.pixelHeight / (int)RayCastingResolution, 0, RenderTextureFormat.ARGBHalf);
            SSR_TraceMask_RT[0].filterMode = FilterMode.Point;
            SSR_TraceMask_ID[0] = SSR_TraceMask_RT[0].colorBuffer;

            RenderTexture.ReleaseTemporary(SSR_TraceMask_RT[1]);
            SSR_TraceMask_RT[1] = RenderTexture.GetTemporary(RenderCamera.pixelWidth / (int)RayCastingResolution, RenderCamera.pixelHeight / (int)RayCastingResolution, 0, RenderTextureFormat.ARGBHalf);
            SSR_TraceMask_RT[1].filterMode = FilterMode.Point;
            SSR_TraceMask_ID[1] = SSR_TraceMask_RT[1].colorBuffer;

            ////////////Spatial RT
            RenderTexture.ReleaseTemporary(SSR_Spatial_RT);
            SSR_Spatial_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.ARGBHalf); 
            SSR_Spatial_RT.filterMode = FilterMode.Bilinear;

            ////////////Temporal RT
            RenderTexture.ReleaseTemporary(SSR_TemporalPrev_RT);
            SSR_TemporalPrev_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.ARGBHalf); 
            SSR_TemporalPrev_RT.filterMode = FilterMode.Bilinear;

            RenderTexture.ReleaseTemporary(SSR_TemporalCurr_RT);
            SSR_TemporalCurr_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.ARGBHalf); 
            SSR_TemporalCurr_RT.filterMode = FilterMode.Bilinear;

            ////////////Combine RT
            RenderTexture.ReleaseTemporary(SSR_CombineScene_RT);
            SSR_CombineScene_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.DefaultHDR); 
            SSR_CombineScene_RT.filterMode = FilterMode.Point;

            ////////////Update Uniform Variable
            SSR_UpdateUniformVariable();
        }

        ////////////Set Matrix
#if UNITY_EDITOR
        if (RunTimeDebugMod) {
            SSR_UpdateUniformVariable();
        }
#endif

        StochasticScreenSpaceReflectionMaterial.SetVector(SSR_Jitter_ID, new Vector4((float)CameraSize.x / 1024, (float)CameraSize.y / 1024, RandomSampler.x, RandomSampler.y));
        SSR_WorldToCameraMatrix = RenderCamera.worldToCameraMatrix;
        SSR_CameraToWorldMatrix = SSR_WorldToCameraMatrix.inverse;
        SSR_ProjectionMatrix = GL.GetGPUProjectionMatrix(RenderCamera.projectionMatrix, false);
        SSR_ViewProjectionMatrix = SSR_ProjectionMatrix * SSR_WorldToCameraMatrix;
        StochasticScreenSpaceReflectionMaterial.SetMatrix(SSR_ProjectionMatrix_ID, SSR_ProjectionMatrix);
        StochasticScreenSpaceReflectionMaterial.SetMatrix(SSR_ViewProjectionMatrix_ID, SSR_ViewProjectionMatrix);
        StochasticScreenSpaceReflectionMaterial.SetMatrix(SSR_InverseProjectionMatrix_ID, SSR_ProjectionMatrix.inverse);
        StochasticScreenSpaceReflectionMaterial.SetMatrix(SSR_InverseViewProjectionMatrix_ID, SSR_ViewProjectionMatrix.inverse);
        StochasticScreenSpaceReflectionMaterial.SetMatrix(SSR_WorldToCameraMatrix_ID, SSR_WorldToCameraMatrix);
        StochasticScreenSpaceReflectionMaterial.SetMatrix(SSR_CameraToWorldMatrix_ID, SSR_CameraToWorldMatrix);
        StochasticScreenSpaceReflectionMaterial.SetMatrix(SSR_LastFrameViewProjectionMatrix_ID, SSR_Prev_ViewProjectionMatrix);

        Matrix4x4 warpToScreenSpaceMatrix = Matrix4x4.identity;
        warpToScreenSpaceMatrix.m00 = HalfCameraSize.x; warpToScreenSpaceMatrix.m03 = HalfCameraSize.x;
        warpToScreenSpaceMatrix.m11 = HalfCameraSize.y; warpToScreenSpaceMatrix.m13 = HalfCameraSize.y;

        Matrix4x4 SSR_ProjectToPixelMatrix = warpToScreenSpaceMatrix * SSR_ProjectionMatrix;
        StochasticScreenSpaceReflectionMaterial.SetMatrix(SSR_ProjectToPixelMatrix_ID, SSR_ProjectToPixelMatrix);
        
        Vector4 SSR_ProjInfo = new Vector4
                ((-2 / (CameraSize.x * SSR_ProjectionMatrix[0])),
                (-2 / (CameraSize.y * SSR_ProjectionMatrix[5])),
                ((1 - SSR_ProjectionMatrix[2]) / SSR_ProjectionMatrix[0]),
                ((1 + SSR_ProjectionMatrix[6]) / SSR_ProjectionMatrix[5]));
        StochasticScreenSpaceReflectionMaterial.SetVector(SSR_ProjInfo_ID, SSR_ProjInfo);

        Vector3 SSR_ClipInfo = (float.IsPositiveInfinity(RenderCamera.farClipPlane)) ?
                new Vector3(RenderCamera.nearClipPlane, -1, 1) :
                new Vector3(RenderCamera.nearClipPlane * RenderCamera.farClipPlane, RenderCamera.nearClipPlane - RenderCamera.farClipPlane, RenderCamera.farClipPlane);
        StochasticScreenSpaceReflectionMaterial.SetVector(SSR_CameraClipInfo_ID, SSR_ClipInfo);
    }



    private void RenderScreenSpaceReflection() {
        ScreenSpaceReflectionBuffer.Clear();

        //////Set HierarchicalDepthRT//////
        ScreenSpaceReflectionBuffer.Blit(BuiltinRenderTextureType.ResolvedDepth, SSR_HierarchicalDepth_RT);
        for (int i = 1; i < HiZ_MaxLevel; ++i)
        {
            ScreenSpaceReflectionBuffer.SetGlobalInt(SSR_HiZ_PrevDepthLevel_ID, i - 1);
            ScreenSpaceReflectionBuffer.SetRenderTarget(SSR_HierarchicalDepth_BackUp_RT, i);
            ScreenSpaceReflectionBuffer.DrawMesh(GraphicsUtility.mesh, Matrix4x4.identity, StochasticScreenSpaceReflectionMaterial, 0, RenderPass_HiZ_Depth);
            ScreenSpaceReflectionBuffer.CopyTexture(SSR_HierarchicalDepth_BackUp_RT, 0, i, SSR_HierarchicalDepth_RT, 0, i);
        }
        ScreenSpaceReflectionBuffer.SetGlobalTexture(SSR_HierarchicalDepth_ID, SSR_HierarchicalDepth_RT);

        //////Set SceneColorRT//////
        ScreenSpaceReflectionBuffer.SetGlobalTexture(SSR_SceneColor_ID, SSR_SceneColor_RT);
        ScreenSpaceReflectionBuffer.CopyTexture(BuiltinRenderTextureType.CameraTarget, SSR_SceneColor_RT);

        //////RayCasting//////
        ScreenSpaceReflectionBuffer.SetGlobalTexture(SSR_Trace_ID, SSR_TraceMask_RT[0]);
        ScreenSpaceReflectionBuffer.SetGlobalTexture(SSR_Mask_ID, SSR_TraceMask_RT[1]);
        if(TraceMethod == TraceApprox.HiZTrace) {
            ScreenSpaceReflectionBuffer.BlitMRT(SSR_TraceMask_ID, SSR_TraceMask_RT[0], StochasticScreenSpaceReflectionMaterial, (RayNums > 1) ? RenderPass_HiZ3D_MultiSpp : RenderPass_HiZ3D_SingelSpp);
        } else {
            ScreenSpaceReflectionBuffer.BlitMRT(SSR_TraceMask_ID, SSR_TraceMask_RT[0], StochasticScreenSpaceReflectionMaterial, (RayNums > 1) ? RenderPass_Linear2D_MultiSPP : RenderPass_Linear2D_SingelSPP);
        }

        //////Spatial filter//////  
        ScreenSpaceReflectionBuffer.SetGlobalTexture(SSR_Spatial_ID, SSR_Spatial_RT);
        ScreenSpaceReflectionBuffer.BlitSRT(SSR_Spatial_RT, StochasticScreenSpaceReflectionMaterial, (RayNums > 1) ? RenderPass_Spatiofilter_MultiSPP : RenderPass_Spatiofilter_SingleSPP);
        ScreenSpaceReflectionBuffer.CopyTexture(SSR_Spatial_RT, SSR_TemporalCurr_RT);

        //////Temporal filter//////
        ScreenSpaceReflectionBuffer.SetGlobalTexture(SSR_TemporalPrev_ID, SSR_TemporalPrev_RT);
        ScreenSpaceReflectionBuffer.SetGlobalTexture(SSR_TemporalCurr_ID, SSR_TemporalCurr_RT);
        ScreenSpaceReflectionBuffer.BlitSRT(SSR_TemporalCurr_RT, StochasticScreenSpaceReflectionMaterial, (RayNums > 1) ? RenderPass_Temporalfilter_MultiSpp : RenderPass_Temporalfilter_SingleSPP);
        ScreenSpaceReflectionBuffer.CopyTexture(SSR_TemporalCurr_RT, SSR_TemporalPrev_RT);

        //////Combien Reflection//////
        ScreenSpaceReflectionBuffer.SetGlobalTexture(SSR_CombineScene_ID, SSR_CombineScene_RT);
#if UNITY_EDITOR
        ScreenSpaceReflectionBuffer.BlitSRT(SSR_CombineScene_RT, BuiltinRenderTextureType.CameraTarget, StochasticScreenSpaceReflectionMaterial, (int)DeBugPass);
#else
        ScreenSpaceReflectionBuffer.BlitSRT(SSR_CombineScene_RT, BuiltinRenderTextureType.CameraTarget, StochasticScreenSpaceReflectionMaterial, 9);
#endif

        //////Set Last Frame ViewProjection//////
        SSR_Prev_ViewProjectionMatrix = SSR_ViewProjectionMatrix;
    }



    private void ReleaseSSRBuffer() {
        RenderTexture.ReleaseTemporary(SSR_HierarchicalDepth_RT);
        RenderTexture.ReleaseTemporary(SSR_SceneColor_RT);
        RenderTexture.ReleaseTemporary(SSR_TraceMask_RT[0]);
        RenderTexture.ReleaseTemporary(SSR_TraceMask_RT[1]);
        RenderTexture.ReleaseTemporary(SSR_Spatial_RT);
        RenderTexture.ReleaseTemporary(SSR_TemporalPrev_RT);
        RenderTexture.ReleaseTemporary(SSR_TemporalCurr_RT);
        RenderTexture.ReleaseTemporary(SSR_CombineScene_RT);

        if (ScreenSpaceReflectionBuffer != null) {
            ScreenSpaceReflectionBuffer.Dispose();
        }
    }

}

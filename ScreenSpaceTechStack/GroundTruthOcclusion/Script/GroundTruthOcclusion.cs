using UnityEngine;
using System.Collections;
using UnityEngine.Rendering;
using System.Collections.Generic;

[ExecuteInEditMode]
[ImageEffectAllowedInSceneView]
[RequireComponent(typeof(Camera))]
public class GroundTruthOcclusion : MonoBehaviour {

    //////Enum Property//////
    public enum SSAO_OutPass
    {
        Combien = 5,
        AO = 6,
        RO = 7,
    };

    public enum SSAO_RenderResolution
    {
        Full = 1,
        Half = 2,
    };



//////C# To Shader Property
    ///Public
    [Header("RenderProperty")]

    [SerializeField]
    SSAO_RenderResolution RenderSize = SSAO_RenderResolution.Half;


    [SerializeField]
    Texture GTSO_LUT = null;


    [SerializeField]
    [Range(1, 4)]
    int DirSampler = 2;


    [SerializeField]
    [Range(1, 8)]
    int SliceSampler = 2;


    [SerializeField]
    [Range(1, 5)]
    float Radius = 2.5f;


    [SerializeField]
    [Range(0, 1)]
    float Intensity = 1;


    [SerializeField]
    [Range(1, 8)]
    float Power = 2.5f;


    [SerializeField]
    bool MultiBounce = true;



    [Header("FiltterProperty")]

    [Range(0, 1)]
    [SerializeField]
    float Sharpeness = 0.2f;

    [Range(1, 5)]
    [SerializeField]
    float TemporalScale = 1.25f;

    [Range(0, 0.99f)]
    [SerializeField]
    float TemporalWeight = 0.99f;



    [Header("DeBugProperty")]

    [SerializeField]
    private SSAO_OutPass AODeBug = SSAO_OutPass.Combien;




    //////BaseProperty
    private Camera RenderCamera;
    private Material GTAOMaterial;
    private CommandBuffer GTAOBuffer = null;


    //////Transform property 
    private Matrix4x4 SSAO_ProjectionMatrix;
    private Matrix4x4 SSAO_ViewProjectionMatrix;
    private Matrix4x4 SSAO_InverseViewProjectionMatrix;
    private Matrix4x4 SSAO_WorldToCameraMatrix;


    ////// private
    private Vector2 CameraSize;
    private Vector2 RenderResolution;
    private Vector4 SSAO_UVToView;
    private Vector4 SSAO_TexelSize;


    private RenderTexture SSAO_SceneColor_RT, SSAO_Occlusion_RT, SSAO_UpOcclusion_RT, SSAO_Spatial_RT, SSAO_TemporalPrev_RT, SSAO_TemporalCurr_RT, SSAO_CombineScene_RT;


    private uint m_sampleStep = 0;
	private static readonly float[] m_temporalRotations = {60, 300, 180, 240, 120, 0};
	private static readonly float[] m_spatialOffsets = {0, 0.5f, 0.25f, 0.75f};



    //////Shader Property
    private static int SSAO_WorldToCameraMatrix_ID = Shader.PropertyToID("_SSAO_WorldToCameraMatrix");
    private static int SSAO_CameraToWorldMatrix_ID = Shader.PropertyToID("_SSAO_CameraToWorldMatrix");
    private static int SSAO_Inverse_ProjectionMatrix_ID = Shader.PropertyToID("_SSAO_InverseProjectionMatrix");
    private static int SSAO_Inverse_View_ProjectionMatrix_ID = Shader.PropertyToID("_SSAO_InverseViewProjectionMatrix");


    private static int SSAO_GTSO_LUT_ID = Shader.PropertyToID("_SSAO_GTSO_LUT");
    private static int SSAO_DirSampler_ID = Shader.PropertyToID("_SSAO_DirSampler");
    private static int SSAO_SliceSampler_ID = Shader.PropertyToID("_SSAO_SliceSampler");
    private static int SSAO_Power_ID = Shader.PropertyToID("_SSAO_Power");
    private static int SSAO_Intensity_ID = Shader.PropertyToID("_SSAO_Intensity");
    private static int SSAO_Radius_ID = Shader.PropertyToID("_SSAO_Radius");
    private static int SSAO_Sharpeness_ID = Shader.PropertyToID("_SSAO_Sharpeness");
    private static int SSAO_TemporalScale_ID = Shader.PropertyToID("_SSAO_TemporalScale");
    private static int SSAO_TemporalWeight_ID = Shader.PropertyToID("_SSAO_TemporalWeight");
    private static int SSAO_MultiBounce_ID = Shader.PropertyToID("_SSAO_MultiBounce");


    private static int SSAO_HalfProjScale_ID = Shader.PropertyToID("_SSAO_HalfProjScale");
    private static int SSAO_TemporalOffsets_ID = Shader.PropertyToID("_SSAO_TemporalOffsets");
    private static int SSAO_TemporalDirections_ID = Shader.PropertyToID("_SSAO_TemporalDirections");
    private static int SSAO_UVToView_ID = Shader.PropertyToID("_SSAO_UVToView");
    private static int SSAO_TexelSize_ID = Shader.PropertyToID("_SSAO_TexelSize");
    private static int SSAO_ScreenSize_ID = Shader.PropertyToID("_SSAO_ScreenSize");


    private static int SSAO_SceneColor_ID = Shader.PropertyToID("_SSAO_SceneColor_RT");
    private static int SSAO_Occlusion_ID = Shader.PropertyToID("_SSAO_Occlusion_RT");
    private static int SSAO_UpOcclusion_ID = Shader.PropertyToID("_SSAO_UpOcclusion_RT");
    private static int SSAO_Spatial_ID = Shader.PropertyToID("_SSAO_Spatial_RT");
    private static int SSAO_TemporalPrev_ID = Shader.PropertyToID("_SSAO_TemporalPrev_RT");
    private static int SSAO_TemporalCurr_ID = Shader.PropertyToID("_SSAO_TemporalCurr_RT");
    private static int SSAO_CombineScene_ID = Shader.PropertyToID("_SSAO_CombineScene_RT");
    private static int SSAO_GTOTexture2SSR_ID = Shader.PropertyToID("_SSAO_GTOTexture2SSR_RT");

/* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* *//* */
    void Awake()
    {
        RenderCamera = gameObject.GetComponent<Camera>();
        GTAOMaterial = new Material(Shader.Find("Hidden/GroundTruthAmbientOcclusion"));
    }

    void OnEnable()
    {
        GTAOBuffer = new CommandBuffer();
        GTAOBuffer.name = "GroundTruthAmbientOcclusion";
        RenderCamera.AddCommandBuffer(CameraEvent.BeforeLighting, GTAOBuffer);
    }

    void OnPreRender()
    {
        RenderResolution = new Vector2(RenderCamera.pixelWidth, RenderCamera.pixelHeight);

        if (GTAOBuffer != null)
        {
            UpdateVariable_SSAO();
            RenderSSAO();
        }
    }

    void OnDisable()
    {
        if (GTAOBuffer != null) {
            RenderCamera.RemoveCommandBuffer(CameraEvent.BeforeLighting, GTAOBuffer);
        }
    }

    private void OnDestroy()
    {
        RenderTexture.ReleaseTemporary(SSAO_SceneColor_RT);
        RenderTexture.ReleaseTemporary(SSAO_Occlusion_RT);
        RenderTexture.ReleaseTemporary(SSAO_UpOcclusion_RT);
        RenderTexture.ReleaseTemporary(SSAO_Spatial_RT);
        RenderTexture.ReleaseTemporary(SSAO_TemporalPrev_RT);
        RenderTexture.ReleaseTemporary(SSAO_TemporalCurr_RT);
        RenderTexture.ReleaseTemporary(SSAO_CombineScene_RT);

        if (GTAOBuffer != null) {
            GTAOBuffer.Dispose();
        }
    }





    ////////////////////////////////////////////////////////////////SSAO Function////////////////////////////////////////////////////////////////
    private void UpdateVariable_SSAO()
    {
        //----------------------------------------------------------------------------------
        SSAO_WorldToCameraMatrix = RenderCamera.worldToCameraMatrix;
        SSAO_ProjectionMatrix = GL.GetGPUProjectionMatrix(RenderCamera.projectionMatrix, false);
        SSAO_ViewProjectionMatrix = SSAO_ProjectionMatrix * SSAO_WorldToCameraMatrix;

        GTAOMaterial.SetMatrix(SSAO_WorldToCameraMatrix_ID, SSAO_WorldToCameraMatrix);
        GTAOMaterial.SetMatrix(SSAO_CameraToWorldMatrix_ID, SSAO_WorldToCameraMatrix.inverse);
        GTAOMaterial.SetMatrix(SSAO_Inverse_ProjectionMatrix_ID, SSAO_ProjectionMatrix.inverse);
        GTAOMaterial.SetMatrix(SSAO_Inverse_View_ProjectionMatrix_ID, SSAO_ViewProjectionMatrix.inverse);

        //----------------------------------------------------------------------------------
        GTAOMaterial.SetInt(SSAO_MultiBounce_ID, MultiBounce ? 1 : 0);
        GTAOMaterial.SetFloat(SSAO_DirSampler_ID, DirSampler);
        GTAOMaterial.SetFloat(SSAO_SliceSampler_ID, SliceSampler);
        GTAOMaterial.SetFloat(SSAO_Intensity_ID, Intensity);
        GTAOMaterial.SetFloat(SSAO_Radius_ID, Radius);
        GTAOMaterial.SetFloat(SSAO_Power_ID, Power);
        GTAOMaterial.SetFloat(SSAO_Sharpeness_ID, Sharpeness);
        GTAOMaterial.SetFloat(SSAO_TemporalScale_ID, TemporalScale);
        GTAOMaterial.SetFloat(SSAO_TemporalWeight_ID, TemporalWeight);
        GTAOMaterial.SetTexture(SSAO_GTSO_LUT_ID, GTSO_LUT);


        //----------------------------------------------------------------------------------
        float fovRad = RenderCamera.fieldOfView * Mathf.Deg2Rad;
        float invHalfTanFov = 1 / Mathf.Tan(fovRad * 0.5f);
        Vector2 focalLen = new Vector2(invHalfTanFov * (((float)RenderResolution.y / (float)RenderSize) / ((float)RenderResolution.x / (float)RenderSize)), invHalfTanFov);
        Vector2 invFocalLen = new Vector2(1 / focalLen.x, 1 / focalLen.y);
        GTAOMaterial.SetVector(SSAO_UVToView_ID, new Vector4(2 * invFocalLen.x, 2 * invFocalLen.y, -1 * invFocalLen.x, -1 * invFocalLen.y));

        //----------------------------------------------------------------------------------
        float projScale = ((float)RenderResolution.y / (float)RenderSize) / (Mathf.Tan(fovRad * 0.5f) * 2) * 0.5f;
        GTAOMaterial.SetFloat(SSAO_HalfProjScale_ID, projScale);

        //----------------------------------------------------------------------------------
        SSAO_TexelSize = new Vector4(1 / ((float)RenderResolution.x / (float)RenderSize), 1 / ((float)RenderResolution.y / (float)RenderSize), (float)RenderResolution.x / (float)RenderSize, (float)RenderResolution.y / (float)RenderSize);
        GTAOMaterial.SetVector(SSAO_TexelSize_ID, SSAO_TexelSize);
        GTAOMaterial.SetVector(SSAO_ScreenSize_ID, new Vector4(1 / (float)RenderResolution.x, 1 / (float)RenderResolution.y, (float)RenderResolution.x, (float)RenderResolution.y));

        //----------------------------------------------------------------------------------
        float temporalRotation = m_temporalRotations[m_sampleStep % 6];
        float temporalOffset = m_spatialOffsets[(m_sampleStep / 6) % 4];
        GTAOMaterial.SetFloat(SSAO_TemporalDirections_ID, temporalRotation / 360);
        GTAOMaterial.SetFloat(SSAO_TemporalOffsets_ID, temporalOffset);
        m_sampleStep++;

        //----------------------------------------------------------------------------------
        Vector2 CurrentCameraSize = new Vector2(RenderCamera.pixelWidth, RenderCamera.pixelHeight);
        if (CameraSize != CurrentCameraSize) 
        {
            CameraSize = CurrentCameraSize;

            ////////////SceneColor RT
            RenderTexture.ReleaseTemporary(SSAO_SceneColor_RT);
            SSAO_SceneColor_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.DefaultHDR); SSAO_SceneColor_RT.filterMode = FilterMode.Bilinear;

            ////////////Occlusion RT
            RenderTexture.ReleaseTemporary(SSAO_Occlusion_RT);
            SSAO_Occlusion_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth / (int)RenderSize, RenderCamera.pixelHeight / (int)RenderSize, 0, RenderTextureFormat.ARGBHalf);

            ////////////Upsampling RT
            RenderTexture.ReleaseTemporary(SSAO_UpOcclusion_RT);
            SSAO_UpOcclusion_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.ARGBHalf);

            ////////////Spatial RT
            RenderTexture.ReleaseTemporary(SSAO_Spatial_RT);
            SSAO_Spatial_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.ARGBHalf);

            ////////////Temporal RT
            RenderTexture.ReleaseTemporary(SSAO_TemporalPrev_RT);
            SSAO_TemporalPrev_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.RGHalf);
            RenderTexture.ReleaseTemporary(SSAO_TemporalCurr_RT);
            SSAO_TemporalCurr_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.RGHalf);

            ////////////Combine RT
            RenderTexture.ReleaseTemporary(SSAO_CombineScene_RT);
            SSAO_CombineScene_RT = RenderTexture.GetTemporary(RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, RenderTextureFormat.DefaultHDR);
        }
    }

    private void RenderSSAO()
    {
        GTAOBuffer.Clear();

        //////Set SceneColor//////
        GTAOBuffer.SetGlobalTexture(SSAO_SceneColor_ID, SSAO_SceneColor_RT);
        GTAOBuffer.CopyTexture(BuiltinRenderTextureType.CameraTarget, SSAO_SceneColor_RT);

        //////Resolve GTAO and BentNormal
        GTAOBuffer.SetGlobalTexture(SSAO_Occlusion_ID, SSAO_Occlusion_RT);
        GTAOBuffer.BlitSRT(SSAO_Occlusion_RT, GTAOMaterial, 0);

        //////Upsampling
        if(RenderSize == SSAO_RenderResolution.Half) { 
            GTAOBuffer.SetGlobalTexture(SSAO_UpOcclusion_ID, SSAO_UpOcclusion_RT);
            GTAOBuffer.BlitSRT(SSAO_UpOcclusion_RT, GTAOMaterial, 1);  
        } else {
            GTAOBuffer.SetGlobalTexture(SSAO_UpOcclusion_ID, SSAO_UpOcclusion_RT);
            GTAOBuffer.CopyTexture(SSAO_Occlusion_RT, SSAO_UpOcclusion_RT);
        }

        //////Spatial filter
        //XBlur
        GTAOBuffer.SetGlobalTexture(SSAO_Spatial_ID, SSAO_Spatial_RT);
        GTAOBuffer.BlitSRT(SSAO_Spatial_RT, GTAOMaterial, 2);
        //YBlur
        GTAOBuffer.Blit(SSAO_Spatial_RT, SSAO_UpOcclusion_RT);
        GTAOBuffer.BlitSRT(SSAO_Spatial_RT, GTAOMaterial, 3);

        //////Temporal filter
        GTAOBuffer.SetGlobalTexture(SSAO_TemporalPrev_ID, SSAO_TemporalPrev_RT);
        GTAOBuffer.SetGlobalTexture(SSAO_TemporalCurr_ID, SSAO_TemporalCurr_RT); 
        GTAOBuffer.BlitSRT(SSAO_TemporalCurr_RT, GTAOMaterial, 4);
        GTAOBuffer.CopyTexture(SSAO_TemporalCurr_RT, SSAO_TemporalPrev_RT);
        //Set AORT To SSR Buffer
        Shader.SetGlobalTexture(SSAO_GTOTexture2SSR_ID, SSAO_TemporalPrev_RT);

        ////// Combien Scene Color
        GTAOBuffer.SetGlobalTexture(SSAO_CombineScene_ID, SSAO_CombineScene_RT);
        GTAOBuffer.BlitSRT(SSAO_CombineScene_RT, BuiltinRenderTextureType.CameraTarget, GTAOMaterial, (int)AODeBug);
    }

}

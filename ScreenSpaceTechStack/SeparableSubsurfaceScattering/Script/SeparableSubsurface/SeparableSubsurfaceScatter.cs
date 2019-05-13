using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering;
using UnityEngine;

[ExecuteInEditMode]
//[ImageEffectAllowedInSceneView]
[RequireComponent(typeof(Camera))]
public class SeparableSubsurfaceScatter : MonoBehaviour {
    
	public bool DisableFPSLimit = false;
	///////SSS Property
    public Texture2D BlueNoise;

	[Range(0,5)]
	public float SubsurfaceScaler = 0.25f;

    public Color SubsurfaceColor;

    public Color SubsurfaceFalloff;


    private Camera RenderCamera = null;
    private CommandBuffer SubsurfaceBuffer = null;
	private Material SubsurfaceEffects= null;
	private List<Vector4> KernelArray = new List<Vector4>();



	///////SSS Buffer
	static int SceneColorID = Shader.PropertyToID("_SceneColor");
	static int Kernel = Shader.PropertyToID("_Kernel");
    static int SSSScaler = Shader.PropertyToID("_SSSScale");
    static int Noise = Shader.PropertyToID("_Noise");
    static int Jitter = Shader.PropertyToID("_Jitter");
    static int screenSize = Shader.PropertyToID("_screenSize");
    static int NoiseSize = Shader.PropertyToID("_NoiseSize");

	void OnEnable() {
        InstanceProperty();
	}

    void OnPreRender() {
        UpdateSubsurface();
    }

    void OnDisable() {
        if (SubsurfaceBuffer != null) {
			RenderCamera.RemoveCommandBuffer(CameraEvent.AfterForwardOpaque, SubsurfaceBuffer);
            SubsurfaceEffects = null;
            SubsurfaceBuffer = null;
            RenderCamera = null;
        }
    }

    private void OnDestroy()  
    {
        if (SubsurfaceBuffer != null)
        {
            SubsurfaceBuffer.Dispose();
        }
    }

	void InstanceProperty() {
        RenderCamera = GetComponent<Camera>();
        RenderCamera.clearStencilAfterLightingPass = true;  //Clear deferred stencil
        if (SubsurfaceEffects == null) {
            SubsurfaceEffects = new Material(Shader.Find("Hidden/SeparableSubsurfaceScatter"));
            SubsurfaceEffects.SetTexture(Noise, BlueNoise);
            SubsurfaceEffects.SetVector(NoiseSize, new Vector2(64, 64));
        }
        if (SubsurfaceBuffer == null) {
            SubsurfaceBuffer = new CommandBuffer();
            SubsurfaceBuffer.name = "Separable Subsurface Scatter";
            RenderCamera.AddCommandBuffer(CameraEvent.AfterForwardOpaque, SubsurfaceBuffer);
        }
	}

	void UpdateSubsurface() {
		///SSS Color
		Vector3 SSSC = Vector3.Normalize(new Vector3 (SubsurfaceColor.r, SubsurfaceColor.g, SubsurfaceColor.b));
		Vector3 SSSFC = Vector3.Normalize(new Vector3 (SubsurfaceFalloff.r, SubsurfaceFalloff.g, SubsurfaceFalloff.b));
		SeparableSSSLibrary.CalculateKernel(KernelArray, 25, SSSC, SSSFC);
        Vector2 jitterSample = GenerateRandomOffset();
        if (SubsurfaceEffects != null) {
            SubsurfaceEffects.SetVector(Jitter, new Vector4((float)BlueNoise.width, (float)BlueNoise.height, jitterSample.x, jitterSample.y));
            SubsurfaceEffects.SetVector(screenSize, new Vector4((float)RenderCamera.pixelWidth, (float)RenderCamera.pixelHeight, 0, 0));
            SubsurfaceEffects.SetVectorArray(Kernel, KernelArray);
            SubsurfaceEffects.SetFloat(SSSScaler, SubsurfaceScaler);
            SubsurfaceEffects.SetFloat("_RandomSeed", Random.Range(0, 100));
        }
		///SSS Buffer
		SubsurfaceBuffer.Clear();
		SubsurfaceBuffer.GetTemporaryRT (SceneColorID, RenderCamera.pixelWidth, RenderCamera.pixelHeight, 0, FilterMode.Trilinear, RenderTextureFormat.DefaultHDR);

        SubsurfaceBuffer.BlitStencil(BuiltinRenderTextureType.CameraTarget, SceneColorID, BuiltinRenderTextureType.CameraTarget, SubsurfaceEffects, 0);
		SubsurfaceBuffer.BlitSRT(SceneColorID, BuiltinRenderTextureType.CameraTarget, SubsurfaceEffects, 1);
    }

    private float GetHaltonValue(int index, int radix) {
        float result = 0f;
        float fraction = 1f / (float)radix;

        while (index > 0) {
            result += (float)(index % radix) * fraction;
            index /= radix;
            fraction /= (float)radix;
        }
        return result;
    }

    private int SampleCount = 64;
    private int SampleIndex = 0;
    private Vector2 GenerateRandomOffset() {
        var offset = new Vector2(GetHaltonValue(SampleIndex & 1023, 2), GetHaltonValue(SampleIndex & 1023, 3));
        if (SampleIndex++ >= SampleCount)
        SampleIndex = 0;
        return offset;
    }
}

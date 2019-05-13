using UnityEngine;

public static class ShaderIDs {
	//Some Examples
	public static int _MainTex = Shader.PropertyToID("_MainTex");
    //Use id value instead of string could have less cost.
    //Set your custom variables here
    public static int _TempTex = Shader.PropertyToID("_TempTex");
    public static int _DepthTex = Shader.PropertyToID("_DepthTexture");
    public static int _MirrorNormal = Shader.PropertyToID("_MirrorNormal");
    public static int _MirrorPos = Shader.PropertyToID("_MirrorPos");
    public static int _BlurOffset = Shader.PropertyToID("_BlurOffset");
}

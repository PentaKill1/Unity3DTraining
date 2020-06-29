// Amplify Shader Editor - Visual Shader Editing Tool
// Copyright (c) Amplify Creations, Lda <info@amplify.pt>

#if UNITY_POST_PROCESSING_STACK_V2
using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

[Serializable]
[PostProcess(typeof(AotuPostFakeDofPPSRenderer), "AotuPostFakeDof", true)]
public sealed class AotuPostFakeDofPPSSettings : PostProcessEffectSettings {
	[Tooltip("MaxBlur")]
	public FloatParameter _MaxBlur = new FloatParameter {value = 3f};

	[Tooltip("FocusCenter")]
	public FloatParameter _FocusCenter = new FloatParameter {value = 0.5f};

	[Tooltip("FocusLenght")]
	public FloatParameter _FocusLenght = new FloatParameter {value = 0.3f};

	[Tooltip("FocusArea")]
	public FloatParameter _FocusArea = new FloatParameter {value = 1.36f};
}

public sealed class AotuPostFakeDofPPSRenderer : PostProcessEffectRenderer<AotuPostFakeDofPPSSettings> {
	public override void Render(PostProcessRenderContext context) {
		var sheet = context.uberSheet;
		sheet.EnableKeyword("FAKE_DOF");
		//sheet.properties.SetFloat(ShaderIDs.MaxBlur, settings._MaxBlur);
		//sheet.properties.SetFloat(ShaderIDs.FocusCenter, settings._FocusCenter);
		//sheet.properties.SetFloat(ShaderIDs.FocusLength, settings._FocusLenght);
		//sheet.properties.SetFloat(ShaderIDs.FocusArea, settings._FocusArea);
	}
}
#endif
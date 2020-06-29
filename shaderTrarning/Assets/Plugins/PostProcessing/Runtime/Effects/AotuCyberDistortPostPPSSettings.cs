// Amplify Shader Editor - Visual Shader Editing Tool
// Copyright (c) Amplify Creations, Lda <info@amplify.pt>
#if UNITY_POST_PROCESSING_STACK_V2
using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

[Serializable]
[PostProcess( typeof( AotuCyberDistortPostPPSRenderer ), PostProcessEvent.AfterStack, "AotuCyberDistortPost", true )]
public sealed class AotuCyberDistortPostPPSSettings : PostProcessEffectSettings
{
	[Tooltip( "UVDistortStrengthX" )]
	public FloatParameter _UVDistortStrengthX1 = new FloatParameter { value = 1f };
	[Tooltip( "UVDistortStrengthY" )]
	public FloatParameter _UVDistortStrengthY1 = new FloatParameter { value = 1f };
	[Tooltip( "Columns Rows Speed StartFrame" )]
	public Vector4Parameter _ColumnsRowsSpeedStartFrame1 = new Vector4Parameter { value = new Vector4(1f,1f,1f,0f) };
	[Tooltip( "RGBSeprater" )]
	public Vector4Parameter _RGBSeprater1 = new Vector4Parameter { value = new Vector4(1f,1f,1f,0f) };
	[Tooltip( "Threshold" )]
	public FloatParameter _Threshold2 = new FloatParameter { value = 0.8352941f };
	[Tooltip( "DistortMap" )]
	public TextureParameter _DistortMap = new TextureParameter {  };
}

public sealed class AotuCyberDistortPostPPSRenderer : PostProcessEffectRenderer<AotuCyberDistortPostPPSSettings>
{
	public override void Render( PostProcessRenderContext context )
	{
		var sheet = context.propertySheets.Get( Shader.Find( "Aotu/CyberDistortPost" ) );
		sheet.properties.SetFloat( "_UVDistortStrengthX1", settings._UVDistortStrengthX1 );
		sheet.properties.SetFloat( "_UVDistortStrengthY1", settings._UVDistortStrengthY1 );
		sheet.properties.SetVector( "_ColumnsRowsSpeedStartFrame1", settings._ColumnsRowsSpeedStartFrame1 );
		sheet.properties.SetVector( "_RGBSeprater1", settings._RGBSeprater1 );
		sheet.properties.SetFloat( "_Threshold2", settings._Threshold2 );
		if(settings._DistortMap.value != null) sheet.properties.SetTexture( "_DistortMap", settings._DistortMap );
		context.command.BlitFullscreenTriangle( context.source, context.destination, sheet, 0 );
	}
}
#endif

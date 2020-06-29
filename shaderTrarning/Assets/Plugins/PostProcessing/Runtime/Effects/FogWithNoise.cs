
using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
namespace UnityEngine.Rendering.PostProcessing
{
    [Serializable]
    [PostProcess(typeof(FogWithNoiseRender), PostProcessEvent.AfterStack, "Custom/FogWithNoise1")]
    public sealed class FogWithNoise : PostProcessEffectSettings
    {
        [Range(0.1f, 3.0f),Tooltip("雾浓度")]
        public FloatParameter fogDensity = new FloatParameter { value = 0f };
        [Tooltip("雾颜色")]
        public ColorParameter fogColor = new ColorParameter {};
        [Tooltip("雾起始位置")]
        public FloatParameter fogStart = new FloatParameter { value = 0f };
        [Tooltip("雾终止位置")]
        public FloatParameter fogEnd = new FloatParameter { value = 0f };
        [Tooltip("雾效噪点图")]
        public TextureParameter noiseTexture = new TextureParameter { value = null };
        [Range(-3f, 3f), Tooltip("雾x轴移动速度")]
        public FloatParameter fogXSpeed = new FloatParameter { value = 0f };
        [Range(-3f, 3f), Tooltip("雾y轴移动速度")]
        public FloatParameter fogYSpeed = new FloatParameter { value = 0f };
        [Range(0.0f, 3.0f), Tooltip("噪点数量级")]
        public FloatParameter noiseAmount = new FloatParameter { value = 0f };
        [Range(0.0f, 3.0f), Tooltip("雾效区域")]
        public FloatParameter area = new FloatParameter { value = 0f };
        [Range(0.0f, 1.0f), Tooltip("雾效内部区域")]
        public FloatParameter inArea = new FloatParameter { value = 0f };
        [Range(0.0f, 1.0f), Tooltip("雾效中心区域X值")]
        public FloatParameter centerX = new FloatParameter { value = 0f };
        [Range(0.0f, 1.0f), Tooltip("雾效中心区域Y值")]
        public FloatParameter centerY = new FloatParameter { value = 0f };
    }


    public sealed class FogWithNoiseRender : PostProcessEffectRenderer<FogWithNoise>
    {

        public override void Render(PostProcessRenderContext context)
        {
            var sheet = context.uberSheet;
            Matrix4x4 frustumCorners = Matrix4x4.identity;
          
            context.camera.depthTextureMode |= DepthTextureMode.Depth;   
            sheet.EnableKeyword("FOGWITHNOISE");
            float fov = context.camera.fieldOfView;
            float near = context.camera.nearClipPlane;
            float aspect = context.camera.aspect;

            float halfHeight = near * Mathf.Tan(fov * 0.5f * Mathf.Deg2Rad);
            Vector3 toRight = context.camera.transform.right * halfHeight * aspect;
            Vector3 toTop = context.camera.transform.up * halfHeight;

            Vector3 topLeft = context.camera.transform.forward * near + toTop - toRight;
            float scale = topLeft.magnitude / near;

            topLeft.Normalize();
            topLeft *= scale;

            Vector3 topRight = context.camera.transform.forward * near + toRight + toTop;
            topRight.Normalize();
            topRight *= scale;

            Vector3 bottomLeft = context.camera.transform.forward * near - toTop - toRight;
            bottomLeft.Normalize();
            bottomLeft *= scale;

            Vector3 bottomRight = context.camera.transform.forward * near + toRight - toTop;
            bottomRight.Normalize();
            bottomRight *= scale;

            if (settings.inArea > settings.area)
            {
                settings.inArea = settings.area;
            }

            frustumCorners.SetRow(0, bottomLeft);
            frustumCorners.SetRow(1, bottomRight);
            frustumCorners.SetRow(2, topRight);
            frustumCorners.SetRow(3, topLeft);
              
            
            sheet.properties.SetMatrix(ShaderIDs.FrustumCornersRay, frustumCorners);

            sheet.properties.SetFloat(ShaderIDs.FogDensity, settings.fogDensity * 2);
            sheet.properties.SetColor(ShaderIDs.FogColor1, settings.fogColor);
            sheet.properties.SetFloat(ShaderIDs.FogStart, settings.fogStart + context.camera.transform.position.y + 128);
            sheet.properties.SetFloat(ShaderIDs.FogEnd, settings.fogEnd + context.camera.transform.position.y + 128);
            if (settings.noiseTexture.value != null)
            {
                sheet.properties.SetTexture(ShaderIDs.NoiseTex, settings.noiseTexture.value);
            }
            sheet.properties.SetFloat(ShaderIDs.FogXSpeed, settings.fogXSpeed);
            sheet.properties.SetFloat(ShaderIDs.FogYSpeed, settings.fogYSpeed);
            sheet.properties.SetFloat(ShaderIDs.NoiseAmount, settings.noiseAmount);
            //material.SetFloat(ShaderIDs.WeakFactor", weakFactor);
            sheet.properties.SetFloat(ShaderIDs.OutArea, settings.area * 2);
            sheet.properties.SetFloat(ShaderIDs.InArea, settings.inArea / 2);
            sheet.properties.SetFloat(ShaderIDs.CenterX, settings.centerX);
            sheet.properties.SetFloat(ShaderIDs.CenterY, settings.centerY);

        }
    }
}



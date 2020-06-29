using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
namespace UnityEngine.Rendering.PostProcessing
{
    [Serializable]
    [PostProcess(typeof(GlitchRenderer), PostProcessEvent.AfterStack, "Custom/Glitch")]
    public sealed class Glitch : PostProcessEffectSettings
    {
        [MinMax(0f, 20f), DisplayName("Rate(0-20)"), Tooltip("干扰频率，在范围内随机")]
        public Vector2Parameter Rate = new Vector2Parameter { value = new Vector2(3f, 5f) };
        [Range(0, 5)]
        public FloatParameter EffectTime = new FloatParameter { value = 0f };
        [Tooltip("是否过度")]
        public BoolParameter ExcessiveMode = new BoolParameter { value = false };
        [Range(0,1), Tooltip("扫描线")]
        public FloatParameter ScanLineJitter = new FloatParameter { value = 0f };
        [Range(0, 1), Tooltip("垂直跳动")]
        public FloatParameter VerticalJump = new FloatParameter { value = 0f };
        [Range(0, 1), Tooltip("左右震动")]
        public FloatParameter HorizontalShake = new FloatParameter { value = 0f };
        [Range(0, 1), Tooltip("颜色偏移")]
        public FloatParameter ColorDrift = new FloatParameter { value = 0f };
    }

    
    public sealed class GlitchRenderer : PostProcessEffectRenderer<Glitch>
    {
        private float _time = 0f;
        private float _T = 0;
        public override void Render(PostProcessRenderContext context)
        {
            
            var sheet = context.uberSheet;
            _time += Time.deltaTime;
            float k = 1.0f;
            if (settings.Rate.value.x != 0 || settings.Rate.value.y != 0)
            {
                if (_T == 0)
                {
                    _T = Random.Range(settings.Rate.value.x, settings.Rate.value.y);
                }
                if (_time < _T)
                {
                    return;
                }
                else if (_time > _T + settings.EffectTime)
                {
                    _time = 0;
                    _T = Random.Range(settings.Rate.value.x, settings.Rate.value.y);
                    sheet.DisableKeyword("GLITCH");
                    return;
                }

              
               
                if (settings.ExcessiveMode)
                {
                    k = ((float)Math.Sin((_time - _T) / settings.EffectTime * Math.PI));
                }
            }
            sheet.EnableKeyword("GLITCH");
            sheet.properties.SetFloat(ShaderIDs.ScanLineJitter, k * settings.ScanLineJitter.value);
            sheet.properties.SetFloat(ShaderIDs.ColorDrift, k * settings.ColorDrift.value);
            sheet.properties.SetFloat(ShaderIDs.VerticalJump, k * settings.VerticalJump.value);
            sheet.properties.SetFloat(ShaderIDs.HorizontalShake, k * settings.HorizontalShake.value);
            //sheet.properties.SetFloat(ShaderIDs.VerticalJump, settings.VerticalJump);
            //sheet.properties.SetFloat(ShaderIDs.HorizontalShake, settings.HorizontalShake);
        }
    }
}

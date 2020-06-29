Shader "Hidden/PostProcessing/Uber"
{
    HLSLINCLUDE

        #pragma target 3.0

        #pragma multi_compile __ DISTORT
        #pragma multi_compile __ CHROMATIC_ABERRATION CHROMATIC_ABERRATION_LOW
        #pragma multi_compile __ BLOOM BLOOM_LOW
        #pragma multi_compile __ VIGNETTE
        #pragma multi_compile __ GRAIN
        #pragma multi_compile __ FINALPASS
        #pragma multi_compile __ GLITCH
		#pragma multi_compile __ FOGWITHNOISE
        // the following keywords are handled in API specific SubShaders below
        // #pragma multi_compile __ COLOR_GRADING_LDR_2D COLOR_GRADING_HDR_2D COLOR_GRADING_HDR_3D
        // #pragma multi_compile __ STEREO_INSTANCING_ENABLED STEREO_DOUBLEWIDE_TARGET
        
        #pragma vertex VertUVTransform
        #pragma fragment FragUber
    
        #include "../StdLib.hlsl"
	    #include "../Colors.hlsl"
        #include "../Sampling.hlsl"
        #include "Distortion.hlsl"
        #include "Dithering.hlsl"
        #define MAX_CHROMATIC_SAMPLES 16

        TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
		
        float4 _MainTex_TexelSize;

        // Auto exposure / eye adaptation
        TEXTURE2D_SAMPLER2D(_AutoExposureTex, sampler_AutoExposureTex);

        // Bloom
        TEXTURE2D_SAMPLER2D(_BloomTex, sampler_BloomTex);
        TEXTURE2D_SAMPLER2D(_Bloom_DirtTex, sampler_Bloom_DirtTex);
        float4 _BloomTex_TexelSize;
        float4 _Bloom_DirtTileOffset; // xy: tiling, zw: offset
        half3 _Bloom_Settings; // x: sampleScale, y: intensity, z: dirt intensity
        half3 _Bloom_Color;

        // Chromatic aberration
        TEXTURE2D_SAMPLER2D(_ChromaticAberration_SpectralLut, sampler_ChromaticAberration_SpectralLut);
        half _ChromaticAberration_Amount;

		//FogWithNoise
		


        // Color grading
    #if COLOR_GRADING_HDR_3D

        TEXTURE3D_SAMPLER3D(_Lut3D, sampler_Lut3D);
        float2 _Lut3D_Params;

    #else

        TEXTURE2D_SAMPLER2D(_Lut2D, sampler_Lut2D);
        float3 _Lut2D_Params;

    #endif

	#if GLITCH
		half _ScanLineJitter; // (displacement, threshold)
		half _VerticalJump;   // (amount, time)
		half _HorizontalShake;
		half _ColorDrift;     // (amount, time)
	#endif

    #if FOGWITHNOISE
		/*ZTest Always Cull Off ZWrite Off*/
		//Fog{ Mode off }
		TEXTURE2D_SAMPLER2D(_NoiseTex, sampler_NoiseTex);
		float4 _NoiseTex_TexelSize;
		TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
		float4x4 _FrustumCornersRay;
		float _FogDensity;
		half4 _FogColor;
		float _FogStart;
		float _FogEnd;
		float _FogXSpeed;
		float _FogYSpeed;
		float _NoiseAmount;
		float3 _worldPosY;
		half _OutArea;
		half _InArea;
		half _CenterX;
		half _CenterY;
	#endif

        half _PostExposure; // EV (exp2)

        // Vignette
        half3 _Vignette_Color;
        half2 _Vignette_Center; // UV space
        half4 _Vignette_Settings; // x: intensity, y: smoothness, z: roundness, w: rounded
        half _Vignette_Opacity;
        half _Vignette_Mode; // <0.5: procedural, >=0.5: masked
        TEXTURE2D_SAMPLER2D(_Vignette_Mask, sampler_Vignette_Mask);

        // Grain
        TEXTURE2D_SAMPLER2D(_GrainTex, sampler_GrainTex);
        half2 _Grain_Params1; // x: lum_contrib, y: intensity
        float4 _Grain_Params2; // x: xscale, h: yscale, z: xoffset, w: yoffset

        // Misc
        half _LumaInAlpha;
		//¼ÆËãÔëÒô¹«Ê½
		float nrand(float x, float y)
		{
			return frac(sin(dot(float2(x, y), float2(12.9898, 78.233))) * 43758.5453);
		}
        half4 FragUber(VaryingsDefault i) : SV_Target
        {
            float2 uv = i.texcoord;

            //>>> Automatically skipped by the shader optimizer when not used
            float2 uvDistorted = Distort(i.texcoord);
            float2 uvStereoDistorted = Distort(i.texcoordStereo);
            //<<<

            // half autoExposure = SAMPLE_TEXTURE2D(_AutoExposureTex, sampler_AutoExposureTex, uv).r;
            half4 color = (0.0).xxxx;

            // Inspired by the method described in "Rendering Inside" [Playdead 2016]
            // https://twitter.com/pixelmager/status/717019757766123520
            #if CHROMATIC_ABERRATION
            {
                float2 coords = 2.0 * uv - 1.0;
                float2 end = uv - coords * dot(coords, coords) * _ChromaticAberration_Amount;

                float2 diff = end - uv;
                int samples = clamp(int(length(_MainTex_TexelSize.zw * diff / 2.0)), 3, MAX_CHROMATIC_SAMPLES);
                float2 delta = diff / samples;
                float2 pos = uv;
                half4 sum = (0.0).xxxx, filterSum = (0.0).xxxx;

                for (int i = 0; i < samples; i++)
                {
                    half t = (i + 0.5) / samples;
                    half4 s = SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, UnityStereoTransformScreenSpaceTex(Distort(pos)), 0);
                    half4 filter = half4(SAMPLE_TEXTURE2D_LOD(_ChromaticAberration_SpectralLut, sampler_ChromaticAberration_SpectralLut, float2(t, 0.0), 0).rgb, 1.0);

                    sum += s * filter;
                    filterSum += filter;
                    pos += delta;
                }

                color = sum / filterSum;
            }
            #elif CHROMATIC_ABERRATION_LOW
            {
                float2 coords = 2.0 * uv - 1.0;
                float2 end = uv - coords * dot(coords, coords) * _ChromaticAberration_Amount;
                float2 delta = (end - uv) / 3;

                half4 filterA = half4(SAMPLE_TEXTURE2D_LOD(_ChromaticAberration_SpectralLut, sampler_ChromaticAberration_SpectralLut, float2(0.5 / 3, 0.0), 0).rgb, 1.0);
                half4 filterB = half4(SAMPLE_TEXTURE2D_LOD(_ChromaticAberration_SpectralLut, sampler_ChromaticAberration_SpectralLut, float2(1.5 / 3, 0.0), 0).rgb, 1.0);
                half4 filterC = half4(SAMPLE_TEXTURE2D_LOD(_ChromaticAberration_SpectralLut, sampler_ChromaticAberration_SpectralLut, float2(2.5 / 3, 0.0), 0).rgb, 1.0);

                half4 texelA = SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, UnityStereoTransformScreenSpaceTex(Distort(uv)), 0);
                half4 texelB = SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, UnityStereoTransformScreenSpaceTex(Distort(delta + uv)), 0);
                half4 texelC = SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, UnityStereoTransformScreenSpaceTex(Distort(delta * 2.0 + uv)), 0);

                half4 sum = texelA * filterA + texelB * filterB + texelC * filterC;
                half4 filterSum = filterA + filterB + filterC;
                color = sum / filterSum;
            }
            #else
            {
                color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uvStereoDistorted);
            }
            #endif

			#if GLITCH
				//É¨ÃèÏß
				float jitter = nrand(uvStereoDistorted.y, _Time.x) * 2 - 1;
				float sx = clamp(1 - _ScanLineJitter * 1.2, 0, 1);
				float sy = 0.002 + pow(_ScanLineJitter, 3) * 0.05;
				jitter *= step(sx, abs(jitter)) * sy;

				//»­Ãæ´¹Ö±Ìø
				float jump = lerp(uvStereoDistorted.y, frac(uvStereoDistorted.y + _VerticalJump * _Time.y * 10), _VerticalJump);
				//float jump = lerp(v, frac(v + _VerticalJump.y), _VerticalJump.x);

				//»­Ãæ×óÓÒÕð¶¯
				float shake = (nrand(_Time.x, 2) - 0.5) * _HorizontalShake * 0.2;

				//ÑÕÉ«Æ«ÒÆ
				float drift = sin(jump + 500) * _ColorDrift * 0.1;

				half4 src1 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, frac(float2(uvStereoDistorted.x + jitter + shake, jump)) );
				half4 src2 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, frac(float2(uvStereoDistorted.x + jitter + shake + drift, jump)));

				#if CHROMATIC_ABERRATION || CHROMATIC_ABERRATION_LOW
					color =  half4(src1.r, src2.g, src1.b, 1)* 0.5 + color *0.5 ;
				#else
					color =  half4(src1.r, src2.g, src1.b, 1) ;
				#endif
				
				//color.g = src2.g;

			#endif

			

            // Gamma space... Gah.
            #if UNITY_COLORSPACE_GAMMA
            {
                color = SRGBToLinear(color);
            }
            #endif

            // color.rgb *= autoExposure;

            #if BLOOM || BLOOM_LOW
            {
                #if BLOOM
                half4 bloom = UpsampleTent(TEXTURE2D_PARAM(_BloomTex, sampler_BloomTex), uvDistorted, _BloomTex_TexelSize.xy, _Bloom_Settings.x);
                #else
                half4 bloom = UpsampleBox(TEXTURE2D_PARAM(_BloomTex, sampler_BloomTex), uvDistorted, _BloomTex_TexelSize.xy, _Bloom_Settings.x);
                #endif

                // UVs should be Distort(uv * _Bloom_DirtTileOffset.xy + _Bloom_DirtTileOffset.zw)
                // but considering we use a cover-style scale on the dirt texture the difference
                // isn't massive so we chose to save a few ALUs here instead in case lens distortion
                // is active
                //half4 dirt = half4(SAMPLE_TEXTURE2D(_Bloom_DirtTex, sampler_Bloom_DirtTex, uvDistorted * _Bloom_DirtTileOffset.xy + _Bloom_DirtTileOffset.zw).rgb, 0.0);

                // Additive bloom (artist friendly)
                bloom *= _Bloom_Settings.y;
                //dirt *= _Bloom_Settings.z;
                color += bloom * half4(_Bloom_Color, 1.0);
                //color += dirt * bloom;
            }
            #endif

            #if VIGNETTE
            {
                UNITY_BRANCH
                if (_Vignette_Mode < 0.5)
                {
                    half2 d = abs(uvDistorted - _Vignette_Center) * _Vignette_Settings.x;
                    d.x *= lerp(1.0, _ScreenParams.x / _ScreenParams.y, _Vignette_Settings.w);
                    d = pow(saturate(d), _Vignette_Settings.z); // Roundness
                    half vfactor = pow(saturate(1.0 - dot(d, d)), _Vignette_Settings.y);
                    color.rgb *= lerp(_Vignette_Color, (1.0).xxx, vfactor);
                    color.a = lerp(1.0, color.a, vfactor);
                }
                else
                {
                    half vfactor = SAMPLE_TEXTURE2D(_Vignette_Mask, sampler_Vignette_Mask, uvDistorted).a;

                    #if !UNITY_COLORSPACE_GAMMA
                    {
                        vfactor = SRGBToLinear(vfactor);
                    }
                    #endif

                    half3 new_color = color.rgb * lerp(_Vignette_Color, (1.0).xxx, vfactor);
                    color.rgb = lerp(color.rgb, new_color, _Vignette_Opacity);
                    color.a = lerp(1.0, color.a, vfactor);
                }
            }
            #endif

            #if GRAIN
            {
                half3 grain = SAMPLE_TEXTURE2D(_GrainTex, sampler_GrainTex, i.texcoordStereo * _Grain_Params2.xy + _Grain_Params2.zw).rgb;

                // Noisiness response curve based on scene luminance
                float lum = 1.0 - sqrt(Luminance(saturate(color)));
                lum = lerp(1.0, lum, _Grain_Params1.x);

                color.rgb += color.rgb * grain * _Grain_Params1.y * lum;
            }
            #endif

            #if COLOR_GRADING_HDR_3D
            {
                color *= _PostExposure;
                float3 colorLutSpace = saturate(LUT_SPACE_ENCODE(color.rgb));
                color.rgb = ApplyLut3D(TEXTURE3D_PARAM(_Lut3D, sampler_Lut3D), colorLutSpace, _Lut3D_Params);
            }
            #elif COLOR_GRADING_HDR_2D
            {
                color *= _PostExposure;
                float3 colorLutSpace = saturate(LUT_SPACE_ENCODE(color.rgb));
                color.rgb = ApplyLut2D(TEXTURE2D_PARAM(_Lut2D, sampler_Lut2D), colorLutSpace, _Lut2D_Params);
            }
            #elif COLOR_GRADING_LDR_2D
            {
                color = saturate(color);

                // LDR Lut lookup needs to be in sRGB - for HDR stick to linear
                color.rgb = LinearToSRGB(color.rgb);
                color.rgb = ApplyLut2D(TEXTURE2D_PARAM(_Lut2D, sampler_Lut2D), color.rgb, _Lut2D_Params);
                color.rgb = SRGBToLinear(color.rgb);
            }
            #endif
			#if FOGWITHNOISE
				float2  uv_depth = i.texcoord;

				#if UNITY_UV_STARTS_AT_TOP
					if(_MainTex_TexelSize.y <0)
					{
						i.texcoord.y = 1 - i.texcoord.y;
					}
				#endif

					int index = 0;
					if (i.texcoord.x < 0.5 && i.texcoord.y < 0.5)
					{
						index = 0;
					}
					else if (i.texcoord.x > 0.5 && i.texcoord.y < 0.5)
					{
						index = 1;
					}
					else if (i.texcoord.x > 0.5 && i.texcoord.y > 0.5)
					{
						index = 2;
					}
					else 
					{
						index = 3;
					}
				#if !UNITY_UV_STARTS_AT_TOP
					if (_MainTex_TexelSize.y < 0)
						index = 3 - index;
				#endif
					float4 interpolateRay = _FrustumCornersRay[index];
		
					float2 dir = i.texcoord - float2(_CenterX, _CenterY);
					float len = sqrt(dir.x*dir.x + dir.y*dir.y);

					float power = 0;
					if (len < _InArea)
					{
						power = 0;
					}
					else if (len > _OutArea)
					{
						power = 1;
					}
					if (len < (_OutArea - _InArea) / 2 + _InArea)
					{
						len = len - _InArea;
						float OutMinusIn = _OutArea - _InArea;
						OutMinusIn = max(0.001, OutMinusIn);
						power = pow(len, 2) / pow(OutMinusIn / 2, 2) * 0.5;
					}
					else
					{
						float L = (_OutArea - _InArea) / 2;
						L = max(0.001, L);
						len = len - _InArea - L;
						power = 1 - (pow((L - len), 2)) / pow(L, 2)*0.5;
					}

					float linearDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord));
					float3 worldPos = _WorldSpaceCameraPos + linearDepth * interpolateRay.xyz;
			
					float2 speed = _Time.y * float2(_FogXSpeed, _FogYSpeed);
					float noise = (SAMPLE_TEXTURE2D(_NoiseTex,sampler_NoiseTex,uv + speed).r - 0.5) * _NoiseAmount;

					float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart);
					fogDensity = saturate(fogDensity * _FogDensity*1.5 * (1 + noise));

					float4 finalColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);

					finalColor.rgb = lerp(finalColor.rgb, _FogColor.rgb, fogDensity * power);
					
					color.rgb = lerp(finalColor.rgb, color.rgb, fogDensity * power);
					
			#endif


            half4 output = color;

            #if FINALPASS
            {
                #if UNITY_COLORSPACE_GAMMA
                {
                    output = LinearToSRGB(output);
                }
                #endif

                output.rgb = Dither(output.rgb, i.texcoord);
            }
            #else
            {
                UNITY_BRANCH
                if (_LumaInAlpha > 0.5)
                {
                    // Put saturated luma in alpha for FXAA - higher quality than "green as luma" and
                    // necessary as RGB values will potentially still be HDR for the FXAA pass
                    half luma = Luminance(saturate(output));
                    output.a = luma;
                }

                #if UNITY_COLORSPACE_GAMMA
                {
                    output = LinearToSRGB(output);
                }
                #endif
            }
            #endif

            // Output RGB is still HDR at that point (unless range was crunched by a tonemapper)
            return output;
        }

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always
		Fog { Mode off }
        Pass
        {
            HLSLPROGRAM
                #pragma exclude_renderers gles vulkan switch

                #pragma multi_compile __ COLOR_GRADING_LDR_2D COLOR_GRADING_HDR_2D COLOR_GRADING_HDR_3D
                #pragma multi_compile __ STEREO_INSTANCING_ENABLED STEREO_DOUBLEWIDE_TARGET
            ENDHLSL
        }
    }

    SubShader
    {
        Cull Off ZWrite Off ZTest Always
		Fog { Mode off }
        Pass
        {
            HLSLPROGRAM
                #pragma only_renderers vulkan switch

                #pragma multi_compile __ COLOR_GRADING_LDR_2D COLOR_GRADING_HDR_2D COLOR_GRADING_HDR_3D
                #pragma multi_compile __ STEREO_DOUBLEWIDE_TARGET // disabled for Vulkan because of shader compiler issues in older Unity versions: STEREO_INSTANCING_ENABLED
            ENDHLSL
        }
    }
    
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
		Fog { Mode off }
        Pass
        {
            HLSLPROGRAM
                #pragma only_renderers gles

                #pragma multi_compile __ COLOR_GRADING_LDR_2D COLOR_GRADING_HDR_2D // not supported by OpenGL ES 2.0: COLOR_GRADING_HDR_3D
                #pragma multi_compile __ STEREO_DOUBLEWIDE_TARGET // not supported by OpenGL ES 2.0: STEREO_INSTANCING_ENABLED
            ENDHLSL
        }
    }
}

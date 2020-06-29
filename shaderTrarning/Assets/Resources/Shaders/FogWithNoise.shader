// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Shaders/Fog/FogWithNoise" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_FogDensity ("Fog Density", Float) = 1.0
		_FogColor ("Fog Color", Color) = (1, 1, 1, 1)
		_FogStart ("Fog Start", Float) = 0.0
		_FogEnd ("Fog End", Float) = 1.0
		_NoiseTex ("Noise Texture", 2D) = "white" {}
		_FogXSpeed ("Fog Horizontal Speed", Float) = 0.1
		_FogYSpeed ("Fog Vertical Speed", Float) = 0.1
		_NoiseAmount ("Noise Amount", Float) = 1
		//_WeakFactor("Weak Factor",Range(1,10)) = 0
		_OutArea("OutArea",Range(0,1)) = 1
		_InArea("InArea",Range(0,1)) = 1
		_CenterX("Center X",Range(0,1)) = 0.5
		_CenterY("Center Y",Range(0,1)) = 0.5
	}
	SubShader {
	ZTest Always Cull Off ZWrite Off
	Fog { Mode off }
		CGINCLUDE
		
		#include "UnityCG.cginc"
		
		float4x4 _FrustumCornersRay;
		
		sampler2D _MainTex;
		half4 _MainTex_TexelSize;
		sampler2D _CameraDepthTexture;
		half _FogDensity;
		fixed4 _FogColor;
		float _FogStart;
		float _FogEnd;
		sampler2D _NoiseTex;
		half _FogXSpeed;
		half _FogYSpeed;
		half _NoiseAmount;
		fixed _OutArea;
		fixed _InArea;
		fixed _CenterX;
		fixed _CenterY;
	//	uniform float _WeakFactor;
		struct v2f {
			float4 pos : SV_POSITION;
			float2 uv : TEXCOORD0;
			float2 uv_depth : TEXCOORD1;
			float4 interpolatedRay : TEXCOORD2;
		};
		
		v2f vert(appdata_img v) {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
			o.uv_depth = v.texcoord;
			
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				o.uv_depth.y = 1 - o.uv_depth.y;
			#endif
			
			int index = 0;
			if (v.texcoord.x < 0.5 && v.texcoord.y < 0.5) {
				index = 0;
			} else if (v.texcoord.x > 0.5 && v.texcoord.y < 0.5) {
				index = 1;
			} else if (v.texcoord.x > 0.5 && v.texcoord.y > 0.5) {
				index = 2;
			} else {
				index = 3;
			}
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				index = 3 - index;
			#endif
			
			o.interpolatedRay = _FrustumCornersRay[index];
				 	 
			return o;
		}
		
		fixed4 frag(v2f i) : SV_Target {

			//float2 uv = min(i.uv, _OutArea);
			//uv = max(i.uv, _InArea);
			
			float2 dir = i.uv  - fixed2(_CenterX,_CenterY);
			//dir.x = min(_OutArea, dir.x);
			//dir.x = max( _InArea , dir.x);
			//dir.y = min(_OutArea, dir.y);
			//dir.y = max( _InArea , dir.y);

			float len = sqrt(dir.x * dir.x + dir.y * dir.y);
			
		//	float power = pow(length(dir ),_WeakFactor);
		//	len = min(len, _OutArea);
		//	len = max(len, _InArea);

			fixed power = 0;
			if (len < _InArea){
				power = 0;
			}else if(len > _OutArea){
				power = 1;
			}else 
			if (len < (_OutArea - _InArea)/2 + _InArea)
			{
				len = len - _InArea;
				float OutMinusIn = _OutArea - _InArea;
				OutMinusIn = max(0.001, OutMinusIn);
				power = pow(len, 2)/pow(OutMinusIn /2, 2) * 0.5;
				//power = 1;
				
			}else{
				float L = (_OutArea - _InArea)/2;
				L = max(0.001, L);
				len = len - _InArea - L;
				power = 1 - ( pow((L - len), 2))/pow(L, 2)*0.5;
				//power = 0.5;
			}

			//power = (len - _InArea) / (_OutArea - _InArea); 


			float linearDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth));
			float3 worldPos = _WorldSpaceCameraPos + linearDepth * i.interpolatedRay.xyz;
			
			float2 speed = _Time.y * float2(_FogXSpeed, _FogYSpeed);
			float noise = (tex2D(_NoiseTex, i.uv + speed).r - 0.5) * _NoiseAmount;
					
			float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart); 
			fogDensity = saturate(fogDensity * _FogDensity * (1 + noise));
			
			fixed4 finalColor = tex2D(_MainTex, i.uv);

			finalColor.rgb = lerp(finalColor.rgb, _FogColor.rgb, fogDensity * power );

			return fixed4(finalColor.rgb, 1);
			//return float4(power,0,0,1);
		}
		
		ENDCG
		
		Pass {          	
			CGPROGRAM  
			
			#pragma vertex vert  
			#pragma fragment frag  
			
			ENDCG
		}
	} 
	FallBack Off
}

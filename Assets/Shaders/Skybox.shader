Shader "Unlit/Skybox"
{
    Properties
    {
        [Header(Sky color)]
        // The HDR color for the top of the skybox
        [HDR]_ColorTop("Color top", Color) = (1,1,1,1)
        // The HDR color for the middle of the skybox
        [HDR]_ColorMiddle("Color middle", Color) = (1,1,1,1)
        // The HDR color for the bottom of the skybox
        [HDR]_ColorBottom("Color bottom", Color) = (1,1,1,1)
        
        // Determines how smoothly the bottom color will blend with the middle color
        _MiddleSmoothness("Middle smoothness", Range(0.0,1.0)) = 1
        // Offsets the start of the middle color in the y-axis
        _MiddleOffset("Middle offset", float) = 0
        // Determines how smoothly the middle color will blend with the top color
        _TopSmoothness("Top smoothness", Range(0.0, 1.0)) = 1
        // Offsets the start of the top color in the y-axis
        _TopOffset("Top offset", float) = 0
        
        [Header(Clouds)]
        [HDR]_CloudsColor("Clouds color", Color) = (1,1,1,1)
        _CloudsTexture("Clouds texture", 2D) = "black" {}
        _CloudsThreshold("Clouds threshold", Range(0.0, 1.0)) = 0
        _CloudsSmoothness("Clouds smoothness", Range(0.0, 1.0)) = 0.1
        _SunCloudsIntensity("Sun behind clouds intensity", Range(0.0, 1.0)) = 0
        _PanningSpeedX("Panning speed X", float) = 0
        _PanningSpeedY("Panning speed Y", float) = 0
        
        [Header(Sun)] 
        _SunSize("Sun size", Range(0.0, 1.0)) = 1
        [HDR]_SunColor("Sun color", color) = (1,1,1,1)
        
        [Header(Moon)]
        _MoonSize("Moon size", Range(0,1)) = 0
        [HDR]_MoonColor("Moon color", Color) = (1,1,1,1)
        _MoonPhase("Moon phase", Range(0,1)) = 0
        
        [Header(Stars)]
        _Stars("Stars", 2D) = "black" {}
        _StarsIntensity("Stars intensity", float) = 0
        
    }
    SubShader
    {
        // Since this is a skybox and we want it render behind everything, we have set a special render type and queue
        Tags { "RenderType"="Background" "Queue"="Background" "PreviewType"="Quad" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                
                // three dimensional instead of two
                float3 uv : TEXCOORD0;
            };

            struct v2_f
            {
                float3 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            // redeclaration of the properties
            fixed4 _ColorTop;
            fixed4 _ColorMiddle;
            fixed4 _ColorBottom;
            
            float _MiddleSmoothness;
            float _MiddleOffset;
            float _TopSmoothness;
            float _TopOffset;

            sampler2D _CloudsTexture;
            float4 _CloudsTexture_ST; // scale of the texture
            fixed4 _CloudsColor;
            float _CloudsSmoothness;
            float _CloudsThreshold;
            float _SunCloudIntensity;
            float _PanningSpeedX;
            float _PanningSpeedY;
            
            fixed4 _SunColor;
            float _SunSize;

            sampler2D _Stars;
            float4 _Stars_ST;
            float _StarsIntensity;

            float _MoonSize;
            fixed4 _MoonColor;
            float _MoonPhase;

            // only need a simple vert shader;v calculates the clip position and passes the UVs to the v2_f
            v2_f vert (appdata v)
            {
                v2_f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2_f i) : SV_Target
            {
                // calculates the UVs for the skybox in a way that eliminates stretching
                float2 uv = float2(atan2(i.uv.x,i.uv.z) / UNITY_TWO_PI, asin(i.uv.y) / UNITY_HALF_PI);

                // calculates the sky's color by defining different color zones, then the three colors are mixed together
                float middleThreshold = smoothstep(0.0, 0.5 - (1.0 - _MiddleSmoothness) / 2.0, i.uv.y - _MiddleOffset);
                float topThreshold = smoothstep(0.5, 1.0 - (1.0 - _TopSmoothness) / 2.0 , i.uv.y - _TopOffset);
                fixed4 col = lerp(_ColorBottom, _ColorMiddle, middleThreshold);
                col = lerp(col, _ColorTop, topThreshold);

                // calc the body of the clouds on the skybox
                float cloudsThreshold = i.uv.y - _CloudsThreshold;
                float cloudsTex = tex2D(_CloudsTexture, uv * _CloudsTexture_ST.xy + _CloudsTexture_ST.zw + float2(_PanningSpeedX, _PanningSpeedY) * _Time.y);
                float clouds = smoothstep(cloudsThreshold, cloudsThreshold + _CloudsSmoothness, cloudsTex);

                // calc the stars that will be visible at night
                float stars = tex2D(_Stars, (i.uv.xz / i.uv.y) * _Stars_ST.xy) * _StarsIntensity * saturate(-_WorldSpaceLightPos0.y) * (1.0 - clouds);
                stars *= smoothstep(0.5,1.0,i.uv.y);
                
                // calculate the shape of the sun using worldspace position of main directional light
                float sunSDF = distance(i.uv.xyz, _WorldSpaceLightPos0);
                // max function is used to keep the sun behind the clouds
                float sun = max(clouds * _CloudsColor.a, smoothstep(0, _SunSize, sunSDF));

                // calc shape of the moon using inverted worldspace position of the main directional light
                float moonSDF = distance(i.uv.xyz, -_WorldSpaceLightPos0);
                float moonPhaseSDF = distance(i.uv.xyz - float3(0.0, 0.0, 0.1) * _MoonPhase, -_WorldSpaceLightPos0);
                float moon = step(moonSDF, _MoonSize);
                moon -= step(moonPhaseSDF, _MoonSize);
                moon = saturate(moon * -_WorldSpaceLightPos0.y - clouds);

                // shading on the clouds
                float cloudShading = smoothstep(cloudsThreshold, cloudsThreshold + _CloudsSmoothness + 0.1, cloudsTex) -
                                     smoothstep(cloudsThreshold + _CloudsSmoothness + 0.1, cloudsThreshold + _CloudsSmoothness + 0.4, cloudsTex);
                // blend between orig cloud shape and shaded one
                clouds = lerp(clouds, cloudShading, 0.5) * middleThreshold * _CloudsColor.a;

                // silver lining when sun is behind clouds
                float silverLining = (smoothstep(cloudsThreshold, cloudsThreshold + _CloudsSmoothness, cloudsTex)
                                    - smoothstep(cloudsThreshold + 0.02, cloudsThreshold + _CloudsSmoothness + 0.02, cloudsTex));
                silverLining *=  smoothstep(_SunSize * 3.0, 0.0, sunSDF) * _CloudsColor.a;

                // put all the colors together
                col = lerp(_SunColor, col, sun);
                fixed4 cloudsCol = lerp(_CloudsColor, _CloudsColor + _SunColor, cloudShading * smoothstep(0.3, 0.0, sunSDF) * _SunCloudIntensity);
                col = lerp(col, cloudsCol, clouds);
                col += silverLining * _SunColor;
                col = lerp(col, _MoonColor, moon);
                col += stars;
                
                return col;
            }
            ENDCG
        }
    }
}

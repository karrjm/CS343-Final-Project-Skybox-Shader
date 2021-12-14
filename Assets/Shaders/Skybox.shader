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
        // HDR cloud color
        [HDR]_CloudsColor("Clouds color", Color) = (1,1,1,1)
        // noise texture used for clouds
        _CloudsTexture("Clouds texture", 2D) = "black" {}
        // determines height which clouds will disolve
        _CloudsThreshold("Clouds threshold", Range(0.0, 1.0)) = 0
        // the smoothness of the edge of the clouds
        _CloudsSmoothness("Clouds smoothness", Range(0.0, 1.0)) = 0.1
        // determines the area where the sun color is applied oin the clouds
        _SunCloudsIntensity("Sun behind clouds intensity", Range(0.0, 1.0)) = 0
        // the panning speed of the clouds, x and y
        _PanningSpeedX("Panning speed X", float) = 0
        _PanningSpeedY("Panning speed Y", float) = 0
        
        [Header(Sun)] 
        // adjusts the size of the sun
        _SunSize("Sun size", Range(0.0, 1.0)) = 1
        // HDR sun color
        [HDR]_SunColor("Sun color", color) = (1,1,1,1)
        
        [Header(Moon)]
        // adjust the size of the moon
        _MoonSize("Moon size", Range(0,1)) = 0
        // HDR moon color
        [HDR]_MoonColor("Moon color", Color) = (1,1,1,1)
        // moon phase, this is used to get he crescent moon shape
        _MoonPhase("Moon phase", Range(0,1)) = 0
        
        [Header(Stars)]
        // texture used for the stars.
        _Stars("Stars", 2D) = "black" {}
        // intensity of the stars, gets multiplied with the color from the _Stars texture
        _StarsIntensity("Stars intensity", float) = 0
        // noise used for star placement
        _Noise("Noise", 2D) = "" {}
        // coefficient applied to grid
        _GridFactor("Star grid factor", float) = 0
        
    }
    SubShader
    {
        // a skybox should render behind everything, so we have set a special render type and queue
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

            // redeclaration of the properties along with "_ST" fields to adjust scaling and offset
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
            sampler2D _Noise;
            float _GridFactor;

            float _MoonSize;
            fixed4 _MoonColor;
            float _MoonPhase;

            // only need a simple vert shader; calculates the clip position and passes the UVs to the v2_f
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

                // attempt at procedural stars
                /*float2 starsUV = i.uv.xz / i.uv.y;
                int starsUVGrid = floor(starsUV);
                float starsUVRemainder = starsUV - starsUVGrid;
                float noise = tex2D(_Noise, _GridFactor);
                int newStarsUV = starsUVRemainder + noise;*/
                
                // calc the stars that will be visible at night
                float stars = tex2D(_Stars, (i.uv.xz / i.uv.y) * _Stars_ST.xy) * _StarsIntensity * saturate(-_WorldSpaceLightPos0.y) * (1.0 - clouds);
                stars *= smoothstep(0.5,1.0,i.uv.y);
                
                // calculate the shape of the sun using worldspace position of main directional light
                float sunSDF = distance(i.uv.xyz, _WorldSpaceLightPos0);
                // max function is used to keep the sun behind the clouds
                float sun = max(clouds * _CloudsColor.a, smoothstep(0, _SunSize, sunSDF));

                // calc shape of the moon using inverted worldspace position of the main directional light
                float moonSDF = distance(i.uv.xyz, -_WorldSpaceLightPos0);
                float moonPhaseSDF = distance(i.uv.xyz - float3(0.1, 0.0, 0.0) * _MoonPhase, -_WorldSpaceLightPos0);
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
                float sunSilverLining = silverLining * smoothstep(_SunSize * 3.0, 0.0, sunSDF) * _CloudsColor.a;
                float moonSilverLining = silverLining * smoothstep(_MoonSize * 3.0, 0.0, moonSDF) * _CloudsColor.a;
                

                // put all the colors together
                // sun color with lerp using sun shpae
                col = lerp(_SunColor, col, sun);
                // color of the clouds with shading and sun color when behind clouds
                fixed4 cloudsCol = lerp(_CloudsColor, _CloudsColor + _SunColor, cloudShading * smoothstep(0.3, 0.0, sunSDF) * _SunCloudIntensity);
                // add cloud color to previous color
                col = lerp(col, cloudsCol, clouds);
                // silver lining for both sun AND moon
                col += sunSilverLining * _SunColor;
                col += moonSilverLining * _MoonColor;
                // moon color
                col = lerp(col, _MoonColor, moon);
                // star colors
                col += stars;
                
                return col;
            }
            ENDCG
        }
    }
}

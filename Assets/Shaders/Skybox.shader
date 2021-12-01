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
                
                return col;
            }
            ENDCG
        }
    }
}

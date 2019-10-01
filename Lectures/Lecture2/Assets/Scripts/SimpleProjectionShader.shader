Shader "Custom/BrokenShader"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        //_MainTex ("Albedo (RGB)", 2D) = "white" {}
        TextureX ("X axis (ZY plane) texture", 2D) = "white" {}
        TextureY ("Y axis (XZ plane) texture", 2D) = "white" {}
        TextureZ ("Z axis (XY plane) texture", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Pass
        {
            // indicate that our pass is the "base" pass in forward
            // rendering pipeline. It gets ambient and main directional
            // light data set up; light direction in _WorldSpaceLightPos0
            // and color in _LightColor0
            Tags {"LightMode"="ForwardBase"}
        
            CGPROGRAM
            #pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc" // for UnityObjectToWorldNormal
            #include "UnityLightingCommon.cginc" // for _LightColor0

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 zy : TEXCOORD0;
                float2 xz : TEXCOORD1;
                float2 xy : TEXCOORD2;
                fixed3 normal : NORMAL;
            };

            v2f vert (appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.zy = v.vertex.zy;
                o.xz = v.vertex.xz;
                o.xy = v.vertex.xy;
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }
            
            sampler2D TextureX, TextureY, TextureZ;

            fixed4 frag (v2f i) : SV_Target
            {
                half nl = max(0, dot(i.normal, _WorldSpaceLightPos0.xyz));
                half3 light = nl * _LightColor0;
                light += ShadeSH9(half4(i.normal,1));
                
                fixed4 col = (
                    tex2D(TextureX, i.zy) * pow(abs(i.normal.x), 3) +
                    tex2D(TextureY, i.xz) * pow(abs(i.normal.y), 3) +
                    tex2D(TextureZ, i.xy) * pow(abs(i.normal.z), 3)
                    );
                col.rgb *= light;
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}

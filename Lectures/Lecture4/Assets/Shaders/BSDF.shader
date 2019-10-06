Shader "0_Custom/BSDF"
{
    Properties
    {
        _BaseColor ("Color", Color) = (0, 0, 0, 1)
        _AmbientColor ("Ambient Color", Color) = (0, 0, 0, 1)
        _Shininess ("Shininess", Float) = 1
        SkyBox ("SkyBox", Cube) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                fixed3 normal : NORMAL;
            };

            struct v2f
            {
                float4 clip : SV_POSITION;
                float4 pos : TEXCOORD1;
                fixed3 normal : NORMAL;
            };

            float4 _AmbientColor;
            float4 _BaseColor;
            float _Shininess;
            samplerCUBE SkyBox;

            v2f vert (appdata v)
            {
                v2f o;
                o.clip = UnityObjectToClipPos(v.vertex);
                o.pos = mul(UNITY_MATRIX_M, v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            static const int N = 1000;
            static const float PI = 3.14159265359;

            int seed;

            float rand() {
                seed = seed * 1664525 + 1013904223;
                return frac(seed / 4294967295.0);
            }

            float3 getPerp(float3 v) {
                if (abs(v.x) >= 0.5 || abs(v.y) >= 0.5) return normalize(float3(v.y, -v.x, 0));
                return normalize(float3(v.z, 0, -v.x));
            }

            float3 getRandomHalfSphere(float3 normal) {
                 float3 plane1 = getPerp(normal);
                 float3 plane2 = cross(normal, plane1);

                 float c = rand();
                 float phi = rand() * 2 * PI;
                 float r = sqrt(1 - c * c);
                 return normal * c + r * cos(phi) * plane1 + r * sin(phi) * plane2;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                seed = 0;
                rand(); seed += i.pos.x * 1e4;
                rand(); seed += i.pos.y * 1e4;
                rand(); seed += i.pos.z * 1e4;
                seed = 10;
                for (int step = 0; step < N; step++) {
                    float3 n = normalize(i.normal);
                    float3 pt = getRandomHalfSphere(normalize(float3(1, 0.5, 0.25)));
                    if (pt.x * pt.x + pt.y * pt.y + pt.z * pt.z < 1 - 1e-6) {
                        return fixed4(0, 0, 1, 0);
                    }
                    if (pt.x * pt.x + pt.y * pt.y + pt.z * pt.z > 1 + 1e-6) {
                        return fixed4(0, 1, 0, 0);
                    }
                    if (dot(n, pt) >= 0.9999) {
                        return fixed4(1, 0, 0, 0);
                    }
                }
                return fixed4(0, 0, 0, 0);
            }
            ENDCG
        }
    }
}

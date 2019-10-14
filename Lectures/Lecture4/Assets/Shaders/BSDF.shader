Shader "0_Custom/BSDF"
{
    Properties
    {
        _DiffuseColor ("Diffuse Color", Color) = (0, 0, 0, 1)
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

            float4 _DiffuseColor;
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

            static const int N = 3000;
            static const float PI = 3.14159265359;

            uint seed;

            #define GENERATOR 1

            float rand() {
                #if GENERATOR == 1
                seed ^= 2747636419u;
                seed *= 2654435769u;
                seed ^= seed >> 16;
                seed *= 2654435769u;
                seed ^= seed >> 16;
                seed *= 2654435769u;
                #else
                seed = seed * 1664525 + 1013904223;
                #endif
                return frac(seed / 4294967295.0);
            }

            float3 getPerp(float3 v) {
                if (abs(v.x) >= 0.5 || abs(v.y) >= 0.5)
                    return normalize(float3(v.y, -v.x, 0));
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

            float3 f(float3 toLight, float3 normal, float3 toView) {
                float lightNormalCos = dot(toLight, normal);
                if (lightNormalCos <= 0) return 0;

                float3 toReflectedLight = reflect(-toLight, normal);
                float reflectedLightViewK = pow(max(0.0, dot(toReflectedLight, toView)), _Shininess);
                return _DiffuseColor * lightNormalCos + float3(1, 1, 1) * reflectedLightViewK;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                seed = 123456789;
                float3 n = normalize(i.normal);
                float3 toView = normalize(_WorldSpaceCameraPos - i.pos.xyz);

                float3 color = 0;
                float3 sumF = 0;
                for (int step = 0; step < N; step++) {
                    float3 toLight = getRandomHalfSphere(n);
                    float3 curF = f(toLight, n, toView);
                    sumF += curF;
                    // Seed may differe between adjacent fragment shaders, so we may
                    // look into completely different points in the texture => disable mipmap
                    // to avoid noisy borders between different seeds.
                    // TODO: this also helps(?) with blurry sides of the sphere.
                    color += curF * texCUBElod(SkyBox, float4(toLight, 0));
                }
                float4 result = 0;
                result.rgb = color / sumF;
                return result;
            }
            ENDCG
        }
    }
}

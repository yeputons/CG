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

            #define GENERATOR_LCG 0
            #define GENERATOR_SHIFTS 1
            #define GENERATOR_MT 2

            #define GENERATOR GENERATOR_MT
            //#define SAMPLE_WHOLE_SPHERE
            //#define SHOW_DISTRIBUTION

            #if GENERATOR == GENERATOR_MT
            void initMT(uint seed, uint m1, uint m2, uint tmat);
            float randomMT();
            #else
            uint seed;
            #endif

            float rand() {
                #if GENERATOR == GENERATOR_MT
                return randomMT();
                #elif GENERATOR == GENERATOR_SHIFTS
                seed ^= 2747636419u;
                seed *= 2654435769u;
                seed ^= seed >> 16;
                seed *= 2654435769u;
                seed ^= seed >> 16;
                seed *= 2654435769u;
                return frac(seed / 4294967295.0);
                #else
                seed = seed * 1664525 + 1013904223;
                return frac(seed / 4294967295.0);
                #endif
            }

            #ifdef SAMPLE_WHOLE_SPHERE
            float3 getRandomSphere() {
                float c = 2 * rand() - 1;
                float phi = rand() * 2 * PI;
                float r = sqrt(1 - c * c);
                return float3(r * cos(phi), c, r * sin(phi));
            }
            #else
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
            #endif

            float3 f(float3 toLight, float3 normal, float3 toView) {
                float lightNormalCos = dot(toLight, normal);
                if (lightNormalCos <= 0) return 0;

                float3 toReflectedLight = reflect(-toLight, normal);
                float reflectedLightViewK = pow(max(0.0, dot(toReflectedLight, toView)), _Shininess);
                return _DiffuseColor * lightNormalCos + float3(1, 1, 1) * reflectedLightViewK;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                #if GENERATOR == GENERATOR_MT
                initMT(234340U, 0xf50a1d49U, 0xffa8ffebU, 0x0bf2bfffU);
                #else
                seed = 123456789;
                #endif
                float3 n = normalize(i.normal);
                float3 toView = normalize(_WorldSpaceCameraPos - i.pos.xyz);
                #ifdef SHOW_DISTRIBUTION
                n = float3(0, 1, 0);
                #endif

                float3 color = 0;
                float3 sumF = 0;
                for (int step = 0; step < N; step++) {
                    #ifdef SAMPLE_WHOLE_SPHERE
                    float3 toLight = getRandomSphere();
                    #else
                    float3 toLight = getRandomHalfSphere(n);
                    #endif
                    #ifdef SHOW_DISTRIBUTION
                    if (dot(toLight, normalize(i.normal)) >= 0.99999) {
                        return float4(1, 1, 1, 0);
                    }
                    #endif
                    float3 curF = f(toLight, n, toView);
                    sumF += curF;
                    // Seed may differe between adjacent fragment shaders, so we may
                    // look into completely different points in the texture => disable mipmap
                    // to avoid noisy borders between different seeds.
                    // TODO: this also helps(?) with blurry sides of the sphere.
                    color += curF * texCUBElod(SkyBox, float4(toLight, 0));
                }
                float4 result = 0;
                #ifndef SHOW_DISTRIBUTION
                result.rgb = color / sumF;
                #endif
                return result;
            }

            // All code Below is ported from TinyMT and as such we affix the original license:
            /*
            Copyright (c) 2011 Mutsuo Saito, Makoto Matsumoto, Hiroshima
            University and The University of Tokyo. All rights reserved.
            Redistribution and use in source and binary forms, with or without
            modification, are permitted provided that the following conditions are
            met:
                * Redistributions of source code must retain the above copyright
                  notice, this list of conditions and the following disclaimer.
                * Redistributions in binary form must reproduce the above
                  copyright notice, this list of conditions and the following
                  disclaimer in the documentation and/or other materials provided
                  with the distribution.
                * Neither the name of the Hiroshima University nor the names of
                  its contributors may be used to endorse or promote products
                  derived from this software without specific prior written
                  permission.
            THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
            "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
            LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
            A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
            OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
            SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
            LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
            DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
            THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
            (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
            OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
            */
            #if GENERATOR == GENERATOR_MT
            // Represents the Mersenne Twistter's Internal State
            struct mersenneTwister {
              uint status[4];
              uint m1;
              uint m2;
              uint tmat;
            } MT;

            // Initialize the Mersenne Twistter.
            void initMT(uint seed, uint m1, uint m2, uint tmat) {
              MT.status[0] = seed;
              MT.status[1] = m1;
              MT.status[2] = m2;
              MT.status[3] = tmat;
              MT.m1 = m1;
              MT.m2 = m2;
              MT.tmat = tmat;

              for (int i = 1; i < 8; i++) {
                MT.status[i & 3] ^= uint(i) + 1812433253U * MT.status[(i - 1) & 3] ^ (MT.status[(i - 1) & 3] >> 30);
              }
              for (int i = 0; i < 12; i++) {
                randomMT();
              }
            }

            // Produce a psuedo-random float value on the range [0, 1]
            float randomMT() {
              uint x = (MT.status[0] & 0x7fffffffU) ^ MT.status[1] ^ MT.status[2];
              uint y = MT.status[3];
              x ^= (x << 1);
              y ^= (y >> 1) ^ x;
              MT.status[0] = MT.status[1];
              MT.status[1] = MT.status[2];
              MT.status[2] = x ^ (y << 10);
              MT.status[3] = y;
              MT.status[1] ^= -(y & 1U) & MT.m1;
              MT.status[2] ^= -(y & 1U) & MT.m2;

              uint t0, t1;
              t0 = MT.status[3];
              t1 = MT.status[0] + (MT.status[2] >> 8);
              t0 ^= t1;
              t0 ^= -(t1 & 1U) & MT.tmat;

              return t0 / 4294967295.0f;
            }
            #endif
            ENDCG
        }
    }
}

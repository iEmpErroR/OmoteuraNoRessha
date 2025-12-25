Shader "Custom/EdgeDetectIDShader"
{
    Properties
    {
        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineWidth("Outline Width", Float) = 0.0012
    }

    SubShader
    {
        Tags
        {
            "RenderPipelin" = "UniversalPipeline"
        }

        Pass
        {
            Name "EdgeDetectID"

            Cull Back
            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                uint vertexID : SV_VertexID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv[8] : TEXCOORED0;
            };

            TEXTURE2D(_IDMask); // ID颜色遮罩纹理
            SAMPLER(sampler_linear_clamp_IDMask);

            CBUFFER_START(UnityPerMaterial)
                half4 _OutlineColor;
                half _OutlineWidth;
            CBUFFER_END

            half GetLuminance(half3 color)
            {
                return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
            }

            Varyings vert(Attributes input)
            {
                Varyings output;

                // 基本变换
                output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
                float2 uv = GetFullScreenTriangleTexCoord(input.vertexID);

                // 轮廓矫正
                const float correction = _ScreenParams.x / _ScreenParams.y;

                // UV偏移
                output.uv[0] = uv + float2(-1, correction)  * _OutlineWidth; // 左上
                output.uv[1] = uv + float2(0, correction)   * _OutlineWidth; // 中上
                output.uv[2] = uv + float2(1, correction)   * _OutlineWidth; // 右上
                output.uv[3] = uv + float2(-1, 0)  * _OutlineWidth; // 左中
                output.uv[4] = uv + float2(1, 0)   * _OutlineWidth; // 右中
                output.uv[5] = uv + float2(-1, -correction) * _OutlineWidth; // 左下
                output.uv[6] = uv + float2(0, -correction)  * _OutlineWidth; // 中下
                output.uv[7] = uv + float2(1, -correction)  * _OutlineWidth; // 右下

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 亮度
                half luminance[8];
                luminance[0] = GetLuminance(SAMPLE_TEXTURE2D_X(_IDMask, sampler_linear_clamp_IDMask, input.uv[0]).rgb);
                luminance[1] = GetLuminance(SAMPLE_TEXTURE2D_X(_IDMask, sampler_linear_clamp_IDMask, input.uv[1]).rgb);
                luminance[2] = GetLuminance(SAMPLE_TEXTURE2D_X(_IDMask, sampler_linear_clamp_IDMask, input.uv[2]).rgb);
                luminance[3] = GetLuminance(SAMPLE_TEXTURE2D_X(_IDMask, sampler_linear_clamp_IDMask, input.uv[3]).rgb);
                luminance[4] = GetLuminance(SAMPLE_TEXTURE2D_X(_IDMask, sampler_linear_clamp_IDMask, input.uv[4]).rgb);
                luminance[5] = GetLuminance(SAMPLE_TEXTURE2D_X(_IDMask, sampler_linear_clamp_IDMask, input.uv[5]).rgb);
                luminance[6] = GetLuminance(SAMPLE_TEXTURE2D_X(_IDMask, sampler_linear_clamp_IDMask, input.uv[6]).rgb);
                luminance[7] = GetLuminance(SAMPLE_TEXTURE2D_X(_IDMask, sampler_linear_clamp_IDMask, input.uv[7]).rgb);

                // Sobel梯度计算
                half Gx = luminance[0] * -1 + luminance[3] * -2 + luminance[5] * -1
                        + luminance[2] *  1 + luminance[4] *  2 + luminance[7] *  1;

                half Gy = luminance[0] * -1 + luminance[1] * -2 + luminance[2] * -1
                        + luminance[5] *  1 + luminance[6] *  2 + luminance[7] *  1;
                
                half G = saturate(abs(Gx) + abs(Gy));

                // 边缘判断
                half isEdge = G > 0.1 ? 1.0 : 0.0;

                // 颜色输出
                half4 edgeColor = lerp(half4(0, 0, 0, 0), _OutlineColor, isEdge);

                return edgeColor;
            }

            ENDHLSL
        }
    }
}

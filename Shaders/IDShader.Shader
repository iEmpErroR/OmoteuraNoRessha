Shader "Custom/IDShader"
{
    Properties
    {
        _ObjectID ("Object ID", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "ObjectID"

            Tags{ "LightMode"="UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual
            Blend One Zero

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            CBUFFER_START(UnityPerMaterial)
                float _ObjectID;
            CBUFFER_END

            // 根据ID快速分配颜色
            half3 FastIDColor(uint id)
            {
                // 预计算的倒数，避免运行时除法
                static const half INV_251 = 1.0 / 251.0;
                static const half INV_241 = 1.0 / 241.0;
                static const half INV_239 = 1.0 / 239.0;
    
                uint r = (id * 127u) % 251u;
                uint g = (id * 251u) % 241u;
                uint b = (id * 241u) % 239u;
    
                half3 color;
                color.r = 0.2 + 0.75 * (r * INV_251); // 限制在 0.2 - 0.95
                color.g = 0.2 + 0.75 * (g * INV_241);
                color.b = 0.2 + 0.75 * (b * INV_239);
    
                return saturate(color);
            }

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                uint idInt = (uint)_ObjectID;
                half3 IDColor = FastIDColor(idInt);

                return half4(IDColor, 1.0);
            }

            ENDHLSL
        }
    }
}

Shader "Custom/StandardToonShader"
{
    Properties
    {
        // 基础属性
        [MainColor] _BaseColor("Color Tint", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo (RGB)", 2D) = "white" {}
        _SpecularTint("Specular Tint", Color) = (1,1,1,1)
        
        // 表面属性
        _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalScale("Normal Scale", Float) = 1.0
        
        // 金属/粗糙度工作流
        _MetallicRoughnessMap("Metallic (R) Roughness (G) AO (B)", 2D) = "white" {}
        _Metallic("Metallic", Range(0, 1)) = 0
        _Roughness("Roughness", Range(0, 1)) = 1.0
        _OcclusionStrength("AO Strength", Range(0, 1)) = 1.0
        
        // 风格化参数
        [Header(Stylization)]
        // 阴影风格化
        _ShadowStep("Shadow Step", Range(0.1, 1)) = 0.5
        _ShadowFeather("Shadow Feather", Range(0.01, 0.5)) = 0.05

        // 边缘光
        _RimColor("Rim Color", Color) = (1,1,1,0.5)
        _RimPower("Rim Power", Range(0.1, 10)) = 3.0
        _RimIntensity("Rim Intensity", Range(0, 2)) = 1.0
        
        // 自发光
        [Header(Emission)]
        _EmissionMap("Emission Map", 2D) = "black" {}
        [HDR] _EmissionColor("Emission Color", Color) = (0,0,0,1)
        _EmissionIntensity("Emission Intensity", Range(0, 10)) = 1.0
        
        // 高级选项
        [Header(Advanced)]
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows("Receive Shadows", Float) = 1
        [Toggle(_ENVIRONMENT_REFLECTIONS)] _EnvironmentReflections("Environment Reflections", Float) = 1
        [Toggle(_VERTEX_SAMPLES_SHADOWS)] _VertexSamplesShadows("Vertex Samples Shadows", Float) = 0
        
        // 渲染状态
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 2
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
        [Toggle] _ZWrite("Z Write", Float) = 1
        [Toggle(_ALPHATEST_ON)] _ALPHATESTON("Alpha Test", Float) = 0
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
            "Queue" = "Geometry"
        }
        
        // 主光照Pass
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            Cull [_Cull]
            
            HLSLPROGRAM
            
            // URP Features
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SHADOW_LOW _SHADOW_MEDIUM _SHADOW_HIGH
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile _ _LIGHT_LAYERS
            #pragma multi_compile _ _FORWARD_PLUS
            
            // Quality Keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fragment _ _WRITE_RENDERING_LAYERS
            
            // Shader Features
            #pragma shader_feature_local_fragment _ENVIRONMENT_REFLECTIONS
            #pragma shader_feature_local _RECEIVE_SHADOWS
            #pragma shader_feature_local _VERTEX_SAMPLES_SHADOWS
            #pragma shader_feature_local _ALPHATEST_ON
            
            // Unity Keywords
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile _ DOTS_INSTANCING_ON
            
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            
            // 结构体定义
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 texcoord     : TEXCOORD0;
                float2 staticLightmapUV   : TEXCOORD1;
                float2 dynamicLightmapUV  : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 positionCS               : SV_POSITION;
                float2 uv                       : TEXCOORD0;
                float3 positionWS               : TEXCOORD1;
                float3 normalWS                 : TEXCOORD2;
                float4 tangentWS                : TEXCOORD3;    // xyz: tangent, w: sign
                
                #if defined(_RECEIVE_SHADOWS)
                    #if defined(_VERTEX_SAMPLES_SHADOWS)
                        float4 shadowCoord      : TEXCOORD4;
                    #else
                        // 空占位符，避免寄存器冲突
                        float4 shadowCoord_unused : TEXCOORD4;
                    #endif
                #endif
                
                DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 5);
                #ifdef DYNAMICLIGHTMAP_ON
                    float2  dynamicLightmapUV   : TEXCOORD6;
                #endif
                
                half4 fogFactorAndVertexLight   : TEXCOORD7; // x: fogFactor, yzw: vertex light
                
                #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
                    half3 viewDirTS             : TEXCOORD8;
                #endif
                
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            // 纹理和采样器定义
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MetallicRoughnessMap);
            SAMPLER(sampler_MetallicRoughnessMap);
            TEXTURE2D(_EmissionMap);
            SAMPLER(sampler_EmissionMap);
            
            // 常量缓冲区
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _SpecularTint;
                half4 _EmissionColor;
                float _NormalScale;
                half _Metallic;
                half _Roughness;
                half _OcclusionStrength;
                float _EmissionIntensity;
                float _ShadowStep;
                float _ShadowFeather;
                half4 _RimColor;
                float _RimPower;
                float _RimIntensity;
                half _Cutoff;
            CBUFFER_END
            
            // 常量定义
            #define EPSILON 1e-6     

            // Generalized-Trowbridge-Reitz（GTR）法线分布函数
            half D_GTR(half roughness, half NdotH)
            {
                half a = roughness * roughness;
                half a2 = a * a;
                half NdotH2 = NdotH * NdotH;
    
                half num = a2;
                half denom = (NdotH2 * (a2 - 1.0) + 1.0);
                denom = PI * denom * denom + EPSILON;
    
                return num / denom;
            }
            
            // Smith几何遮蔽（Schlick-GGX近似）
            half G_Schlick(half NdotV, half NdotL, half roughness)
            {
                half a2 = roughness * roughness;
    
                // 避免除0
                NdotV = max(NdotV, EPSILON);
                NdotL = max(NdotL, EPSILON);
    
                half GGXV = NdotL * (NdotV * (1.0 - a2) + a2);
                half GGXL = NdotV * (NdotL * (1.0 - a2) + a2);
    
                return 0.5 / (GGXV + GGXL + EPSILON);
            }
            
            // Schlick菲涅尔近似
            half3 F_Schlick(half3 F0, half cosTheta)
            {
                half exponent = 5.0; // 标准Schlick指数
                return F0 + (1.0 - F0) * pow(1.0 - cosTheta, exponent);
            }

            // Disney Diffuse(漫反射项)
            half3 DisneyDiffuseTerm(half3 albedo, half metallic, half roughness, half NdotV, half NdotL, half LdotH)
            {
                half FD90 = 0.5 + 2.0 * LdotH * LdotH * roughness;
                half FdV = 1.0 + (FD90 - 1.0) * pow(1.0 - NdotV, 5.0);
                half FdL = 1.0 + (FD90 - 1.0) * pow(1.0 - NdotL, 5.0);
                
                return albedo * (1.0 - metallic) * FdV * FdL * INV_PI;
            }
            
            // 高光反射项
            half3 SpecularTerm(half roughness, half3 LdotH, half NdotV, half NdotL, half NdotH, half VdotH, half3 F0)
            {
                half3 specular = 0;
                
                if (NdotL > 0 && NdotH > 0)
                {
                    
                    half D = D_GTR(roughness, NdotH);
                    half G = G_Schlick(NdotV, NdotL, roughness);
                    half3 F = F_Schlick(F0, VdotH);
                        
                    specular = D * G * F;
                }  
                
                return specular;
            }

            // 基于粗糙度的积分平均菲涅尔
            half3 IntegrateFresnelAnalytical(half3 F0, half NdotV, half roughness)
            {
                // 计算掠射角菲涅尔
                half3 F90 = saturate(50.0 * dot(F0, 0.33));
    
                // 基于粗糙度的混合因子
                half roughnessSq = roughness * roughness;
                half blendFactor = roughnessSq * (1.0 - NdotV);
    
                // 在F0和F90之间插值
                return lerp(F0, F90, blendFactor);
            }
            
            // 计算边缘光
            half3 CalculateRimLight(half NdotV, half3 lightColor)
            {
                // 菲涅尔
                half rimIntensity = pow(1.0 - NdotV, _RimPower) * _RimIntensity;

                return rimIntensity * _RimColor.rgb * lightColor;
            }
            
            // 风格化阴影过渡
            half StylizedShadow(half NdotL)
            {
                return smoothstep(_ShadowStep - _ShadowFeather, 
                                 _ShadowStep + _ShadowFeather, 
                                 NdotL);
            }

            // 描边
            
            // 顶点着色器
            Varyings LitPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                
                // 位置变换
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                
                // 法线和切线
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = normalInput.normalWS;
                output.tangentWS = float4(normalInput.tangentWS, input.tangentOS.w * GetOddNegativeScale());
                
                // UV
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                
                // 阴影坐标
                #if defined(_RECEIVE_SHADOWS) && defined(_VERTEX_SAMPLES_SHADOWS)
                    output.shadowCoord = TransformWorldToShadowCoord(vertexInput.positionWS);
                #endif
                
                // 光照贴图
                OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
                #ifdef DYNAMICLIGHTMAP_ON
                    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                #endif
                
                // 顶点光照和雾
                half3 vertexLight = VertexLighting(output.positionWS, output.normalWS);
                half fogFactor = ComputeFogFactor(output.positionCS.z);
                output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
                
                // 球谐光照
                OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
                
                return output;
            }
            
            // 片元着色器
            half4 LitPassFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                
                // 采样贴图
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                half3 albedo = albedoAlpha.rgb;
                half alpha = albedoAlpha.a;
                
                #ifdef _ALPHATEST_ON
                    clip(alpha - _Cutoff);
                #endif
                
                half4 metallicRoughness = SAMPLE_TEXTURE2D(_MetallicRoughnessMap, sampler_MetallicRoughnessMap, input.uv);
                half metallic = metallicRoughness.r * _Metallic;
                half roughness = metallicRoughness.a * _Roughness;
                half occlusion = lerp(1.0, metallicRoughness.b, _OcclusionStrength);
                
                // 读取或构建切线空间矩阵
                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv), _NormalScale);
                half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, cross(input.normalWS, input.tangentWS.xyz) * input.tangentWS.w, input.normalWS);
                half3 normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
                normalWS = SafeNormalize(normalWS);
                
                // 视角方向
                half3 viewDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));
                half NdotV = saturate(dot(normalWS, viewDirWS));
                
                // 基础反射率
                half3 F0 = lerp(0.04 * _SpecularTint.rgb, albedo, metallic);
                
                // 间接漫反射
                half3 kD = (1.0 - metallic) * (1.0 - F_Schlick(F0, NdotV));
                half3 indirectDiffuse = SampleSH(normalWS) * albedo * kD * occlusion;
                
                // 间接高光反射（IBL）
                half3 indirectSpecular = 0;
                #if defined(_ENVIRONMENT_REFLECTIONS)

                    // 采样环境
                    half3 reflectVector = reflect(-viewDirWS, normalWS);
                    half perceptualRoughness = roughness * (1.7 - 0.7 * roughness);
                    half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
                    half4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, mip);
                    indirectSpecular = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);

                    // 积分平均菲涅尔（解析近似）
                    half3 fresnelAvg = IntegrateFresnelAnalytical(F0, NdotV, roughness);
        
                    // 表面衰减
                    half surfaceReduction = 1.0 / (roughness * roughness + 1.0);
        
                    // 掠射项增强
                    half grazingTerm = saturate((1.0 - roughness) + dot(1.0 - F0, 0.333));
        
                    // 组合所有项 + AO
                    indirectSpecular *= fresnelAvg * surfaceReduction * grazingTerm * occlusion;

                #endif
                
                // 直接光照
                half3 directLighting = 0;
                
                // 主光源
                // 先检查是否接受阴影
                #if !defined(_RECEIVE_SHADOWS)
                    // 不接受阴影，直接使用无阴影的主光源
                    Light mainLight = GetMainLight();
                #else
                    // 接受阴影
                    #if defined(_VERTEX_SAMPLES_SHADOWS)
                        // 顶点采样阴影模式
                        float4 shadowCoord = input.shadowCoord;
                        Light mainLight = GetMainLight(shadowCoord, input.positionWS, 1);
                    #else
                        // 片元采样阴影模式（默认）
                        float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                        Light mainLight = GetMainLight(shadowCoord, input.positionWS, 1);
                    #endif
                #endif

                if (mainLight.distanceAttenuation > 0)
                {
                    half3 lightDir = mainLight.direction; // 光照方向
                    half3 lightColor = mainLight.color * mainLight.shadowAttenuation * mainLight.distanceAttenuation; // 光照衰减
                    half NdotL = saturate(dot(normalWS, lightDir));
                    half3 halfDir = SafeNormalize(viewDirWS + lightDir);
                    half NdotH = saturate(dot(normalWS, halfDir));
                    half VdotH = saturate(dot(viewDirWS, halfDir));
                    half LdotH = saturate(dot(lightDir, halfDir));
                    
                    // 风格化阴影过渡
                    NdotL = lerp(NdotL, StylizedShadow(NdotL), _ShadowFeather > 0);
                    
                    // 计算直接漫反射 directDiffuse
                    half3 directDiffuse = DisneyDiffuseTerm(albedo, metallic, roughness, NdotV, NdotL, LdotH);

                    // 计算直接高光反射 directSpecular
                    half3 directSpecular = SpecularTerm(roughness, LdotH, NdotV, NdotL, NdotH, VdotH, F0);

                    directLighting += (directDiffuse + directSpecular) * PI * NdotL * lightColor;
                    
                    // 添加边缘光
                    directLighting += CalculateRimLight(NdotV, lightColor);
                }
                
                // 附加光源
                #if defined(_ADDITIONAL_LIGHTS)
                    uint pixelLightCount = GetAdditionalLightsCount();
                    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                    {
                        Light light = GetAdditionalLight(lightIndex, input.positionWS, 1);
                        
                        if (light.distanceAttenuation > 0)
                        {
                            half3 lightDir = light.direction;
                            half3 lightColor = light.color * light.shadowAttenuation * light.distanceAttenuation;
                            half NdotL = saturate(dot(normalWS, lightDir));
                            half3 halfDir = SafeNormalize(viewDirWS + lightDir);
                            half NdotH = saturate(dot(normalWS, halfDir));
                            half VdotH = saturate(dot(viewDirWS, halfDir));
                            half LdotH = saturate(dot(lightDir, halfDir));
                    
                            NdotL = lerp(NdotL, StylizedShadow(NdotL), _ShadowFeather > 0);
                    
                            half3 directDiffuse = DisneyDiffuseTerm(albedo, metallic, roughness, NdotV, NdotL, LdotH);
                            half3 directSpecular = SpecularTerm(roughness, LdotH, NdotV, NdotL, NdotH, VdotH, F0);
                            directLighting += (directDiffuse + directSpecular) * PI * NdotL * lightColor;
                        }
                    }
                #endif
                
                // 自发光
                half3 emission = 0;
                #if defined(_EMISSION)
                    emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv).rgb * 
                               _EmissionColor.rgb * _EmissionIntensity;
                #endif
                
                // 组合最终颜色
                half3 finalColor = directLighting + indirectDiffuse + indirectSpecular + emission;
                
                // 应用雾效
                finalColor = MixFog(finalColor, input.fogFactorAndVertexLight.x);
                
                return half4(finalColor, alpha);
            }
            
            ENDHLSL
        }
        
        // 阴影投射Pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]
            
            HLSLPROGRAM
            
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // URP内置阴影投射Pass
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            
            ENDHLSL
        }
        
        // 深度Only Pass（可选，用于深度纹理）
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            
            ColorMask 0
            ZWrite On
            ZTest LEqual
            Cull[_Cull]
            
            HLSLPROGRAM
            
            // URP内置深度纹理Pass
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            
            ENDHLSL
        }
        
        // Meta Pass（光照贴图烘焙）
        Pass
        {
            Name "Meta"
            Tags { "LightMode" = "Meta" }
            
            Cull Off
            
            HLSLPROGRAM
            
            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit
            
            #pragma shader_feature EDITOR_VISUALIZATION
            #pragma shader_feature_local_fragment _SPECULAR_SETUP
            #pragma shader_feature_local_fragment _EMISSION
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half _Cutoff;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            Varyings UniversalVertexMeta(Attributes input)
            {
                Varyings output;
                output.positionCS = MetaVertexPosition(input.positionOS, input.uv1, input.uv2, unity_LightmapST, unity_DynamicLightmapST);
                output.uv = TRANSFORM_TEX(input.uv0, _BaseMap);
                return output;
            }
            
            half4 UniversalFragmentMetaLit(Varyings input) : SV_Target
            {
                MetaInput metaInput = (MetaInput)0;
                
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                metaInput.Albedo = albedoAlpha.rgb;
                metaInput.Emission = 0;
                
                #if defined(_EMISSION)
                    metaInput.Emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv).rgb * 
                                         _EmissionColor.rgb * _EmissionIntensity;
                #endif
                
                return MetaFragment(metaInput);
            }

            
            ENDHLSL
        }
    }
    
    FallBack "Universal Render Pipeline/Lit"
}

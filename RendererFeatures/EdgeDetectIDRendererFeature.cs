using Unity.Properties;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class EdgeDetectIDRendererFeature : ScriptableRendererFeature
{
    public Shader IDShader; // ID颜色化Shader

    [System.Serializable] // 轮廓数据(实例化后可在Inspector中可视化编辑)
    public class OutlineSettings
    {
        public Shader EdgeDetectIDShader; // 轮廓Shader
        public Color OutlineColor = Color.black; // 轮廓颜色
        [Range(0.0f, 0.01f)] public float OutlineWidth = 0.0012f; // 轮廓宽度
        public LayerMask outlineLayer = 7; // Interactable Layer
    }

    // 实例化轮廓设置(在Inspector中可视化编辑)
    public OutlineSettings settings = new OutlineSettings();

    class EdgeDetectIDRenderPass : ScriptableRenderPass
    {
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.

        // 基础数据
        private readonly Material IDMaterial; // ID颜色化Shader
        private readonly Material EdgeDetectIDMaterial; // 轮廓材质
        private readonly OutlineSettings settings; // 轮廓数据
        private readonly MaterialPropertyBlock mpb; // 材质属性块
        private FilteringSettings filteringSettings; // 过滤设置
        private RenderTextureDescriptor rtd; // RT描述符
        private RTHandle IDMask; // ID遮罩纹理

        // 材质数据ID(对应shader中的变量名)
        private int IDMask_ID = Shader.PropertyToID("_IDMask");
        private int outlineColorID = Shader.PropertyToID("_OutlineColor");
        private int outlineWidthID = Shader.PropertyToID("_OutlineWidth");

        // 构造函数
        public EdgeDetectIDRenderPass(Material idm, Material edidm, OutlineSettings settings)
        {
            this.IDMaterial = idm;
            this.EdgeDetectIDMaterial = edidm;
            this.settings = settings;
            mpb = new MaterialPropertyBlock();
            filteringSettings = new FilteringSettings(RenderQueueRange.opaque, settings.outlineLayer, renderingLayerMask: 2);
            rtd = new RenderTextureDescriptor(Screen.width, Screen.height);

            // 渲染时机
            renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        }

        // 执行前的配置
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            // 配置RT描述符
            rtd.width = cameraTextureDescriptor.width;
            rtd.height = cameraTextureDescriptor.height;
            rtd.colorFormat = RenderTextureFormat.ARGB32;
            rtd.depthBufferBits = 0;
            rtd.msaaSamples = 1;

            // 配置RT
            RenderingUtils.ReAllocateIfNeeded(ref IDMask, rtd, FilterMode.Point, TextureWrapMode.Clamp, name: "_IDMask");

            // 执行前 RT的设置和清理
            ConfigureTarget(IDMask);
            ConfigureClear(ClearFlag.All, Color.clear);
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // 材质检测
            if (EdgeDetectIDMaterial == null || IDMaterial == null)
            {
                Debug.LogWarning("Missing material(s), the pass will not execute.");
                return;
            }

            // 获取命令缓冲区
            CommandBuffer cmd = CommandBufferPool.Get("EdgeDetectIDRenderPass");

            // 绘制设置
            var drawSettings = CreateDrawingSettings(new ShaderTagId("UniversalForward"),
                                                        ref renderingData,
                                                        SortingCriteria.CommonOpaque);

            drawSettings.overrideMaterial = IDMaterial;
            drawSettings.overrideMaterialPassIndex = 0;


            // 渲染器列表特征
            var rendererListParams = new RendererListParams(renderingData.cullResults, drawSettings, filteringSettings);

            // 创建渲染列表 以及 绘制渲染列表
            var rendererList = context.CreateRendererList(ref rendererListParams);
            cmd.DrawRendererList(rendererList);

            // 重新设置渲染目标(回归主线)
            cmd.SetRenderTarget(renderingData.cameraData.renderer.cameraColorTargetHandle);

            // 上传材质属性块
            mpb.SetTexture(IDMask_ID, IDMask);
            mpb.SetColor(outlineColorID, settings.OutlineColor);
            mpb.SetFloat(outlineWidthID, settings.OutlineWidth);

            // 绘制屏幕空间三角形(后处理)
            cmd.DrawProcedural(Matrix4x4.identity, EdgeDetectIDMaterial, 0, MeshTopology.Triangles, 3, 1, mpb);

            // 提交命令缓冲区并释放
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        // 释放RT
        public void Dispose()
        {
            IDMask?.Release();
            IDMask = null;
        }
    }

    EdgeDetectIDRenderPass m_EdgeDetectIDRenderPass;
    private Material m_IDMaterial;
    private Material m_EdgeDetectIDMaterial;

    /// <inheritdoc/>
    public override void Create()
    {
        // 清理旧的材质
        CoreUtils.Destroy(m_IDMaterial);
        CoreUtils.Destroy(m_EdgeDetectIDMaterial);

        m_IDMaterial = CoreUtils.CreateEngineMaterial(IDShader);
        m_EdgeDetectIDMaterial = CoreUtils.CreateEngineMaterial(settings.EdgeDetectIDShader);

        // 简化材质检查
        if (m_IDMaterial == null || m_EdgeDetectIDMaterial == null)
        {
            Debug.LogWarning("Failed to create one or more materials for EdgeDetectID");
            return;
        }

        m_EdgeDetectIDRenderPass = new EdgeDetectIDRenderPass(m_IDMaterial, m_EdgeDetectIDMaterial, settings);
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    // 注入渲染通道时机(进'厂'时机)
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // RenderPass_NULL检测
        if (m_EdgeDetectIDRenderPass == null)
        {
            return;
        }

        // 仅在游戏相机和场景视图相机中开启轮廓渲染通道
        if (renderingData.cameraData.cameraType == CameraType.Game ||
            renderingData.cameraData.cameraType == CameraType.SceneView)
        {
            renderer.EnqueuePass(m_EdgeDetectIDRenderPass);
        }
    }

    // 清理渲染过程中动态创建的资源
    protected override void Dispose(bool disposing)
    {
        m_EdgeDetectIDRenderPass?.Dispose();

        if (disposing)
        {
            CoreUtils.Destroy(m_IDMaterial);
            CoreUtils.Destroy(m_EdgeDetectIDMaterial);
            m_IDMaterial = null;
            m_EdgeDetectIDMaterial = null;
        }
    }
}

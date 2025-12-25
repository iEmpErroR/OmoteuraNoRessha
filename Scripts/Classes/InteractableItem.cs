using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

public class InteractableItem : MonoBehaviour
{
    // ID
    public static int nextID = 1; // 静态变量用于分配唯一ID
    private int ID; // 当前物体的ID

    // 可交互状态
    private bool isInteractable;
    public bool IsInteractable
    {
        get // 获取可交互状态
        {
            return isInteractable;
        }
    }

    // 已交互状态
    private bool hasBeenInteracted;
    public bool HasBeenInteracted
    {
        get // 获取已交互状态
        {
            return hasBeenInteracted;
        }
    }

    // 鼠标悬停状态
    private bool isMouseHovering;
    public bool IsMouseHovering
    {
        get
        {
            return isMouseHovering;
        }
    }

    // 获取 Collider 组件
    private Collider itemCollider;

    private void Awake()
    {
        // 分配ID
        this.ID = InteractableItem.nextID++;
    }

    // Start is called before the first frame update
    void Start()
    {
        // 上传ID
        UploadID();

        // 状态初始化
        isInteractable = false;
        hasBeenInteracted = false;
        isMouseHovering = false;

        itemCollider = GetComponent<Collider>();

        // 尝试向交互管理器注册自己
        if (InteractionManager.Instance != null)
        {
            InteractionManager.Instance.RegisterInteractable(this);
        }
        else
        {
            Debug.LogWarning($"[{gameObject.name}]: Couldn't find InteractionManager!");
        }
    }

    // Update is called once per frame
    void Update()
    {

    }

    #region 公共方法

    // 启用交互
    public void EnableInteractable()
    {
        isInteractable = true;
        Debug.Log($"[{gameObject.name}] is interactable now...");
    }

    // 禁用交互
    public void DisableInteractable()
    {
        isInteractable = false;
        Debug.Log($"[{gameObject.name}] is not interactable now...");

        // 如果当前是悬停状态，需要停止悬停并触发离开事件
        if (IsMouseHovering)
        {
            StopHovering();
            OnMouseExitItem();
        }
    }

    // 切换交互状态
    public void ToggleInteractable()
    {
        if (isInteractable)
        {
            DisableInteractable();
        }
        else
        {
            EnableInteractable();
        }
    }

    #endregion 

    #region 私有方法

    // 上传ID
    private void UploadID()
    {
        // 创建材质属性块并设置ID
        MaterialPropertyBlock mpb = new MaterialPropertyBlock();
        mpb.SetFloat("_ObjectID", ID);

        // 获取所有子渲染器并上传属性块
        Renderer[] allRenderers = GetComponentsInChildren<Renderer>();
        foreach (Renderer renderer in allRenderers)
        {
            renderer.SetPropertyBlock(mpb);

            // 调试输出
            MaterialPropertyBlock debugMPB = new MaterialPropertyBlock();
            renderer.GetPropertyBlock(debugMPB);
            float debugID = debugMPB.GetFloat("_ObjectID");
            Debug.Log($"[{renderer.gameObject.name}] uploaded ID: {ID}");
            Debug.Log($"设置ID: {ID}, 读取ID: {debugID}");
        }
    }

    // 标记为已交互
    private void SetInteracted()
    {
        hasBeenInteracted = true;
        Debug.Log($"[{gameObject.name}] has been interacted...");
    }

    // 开始悬停状态
    private void StartHovering()
    {
        isMouseHovering = true;
        Debug.Log($"[{gameObject.name}] is being hovered by mouse...");
    }

    // 停止悬停状态
    private void StopHovering()
    {
        isMouseHovering = false;
        Debug.Log($"[{gameObject.name}] is not being hovered by mouse anymore...");
    }

    // 执行交互
    private void Interact()
    {
        // 标记为已交互，并关闭可交互状态
        SetInteracted();
        DisableInteractable();

        // 触发交互事件逻辑
        EventManager.TriggerInteract();
    }

    #endregion 

    #region 由交互管理器调用的鼠标相关方法

    // 当鼠标进入物体范围内时调用
    public void OnMouseEnterItem()
    {
        if (!IsMouseHovering && isInteractable)
        {
            StartHovering();
            Debug.Log($"[{gameObject.name}] 鼠标进入物体范围");

            // 可以在这里添加视觉效果
            // ChangeMaterial(highlightMaterial);
        }
    }

    // 当鼠标离开物体范围时调用
    public void OnMouseExitItem()
    {
        if (IsMouseHovering)
        {
            StopHovering();
            Debug.Log($"[{gameObject.name}] 鼠标离开物体范围");

            // 恢复原始材质
            // ChangeMaterial(originalMaterial);
        }
    }

    // 当鼠标点击物体时调用
    public void OnMouseClickItem()
    {
        if (isInteractable)
        {
            Debug.Log($"[{gameObject.name}] 被点击了");
            Interact();
        }
    }

    #endregion 
}

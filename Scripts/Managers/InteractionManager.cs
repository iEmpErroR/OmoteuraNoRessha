using System.Collections.Generic;
using UnityEngine;

public class InteractionManager : MonoBehaviour
{
    public static InteractionManager Instance { get; private set; }

    [Header("交互设置")]
    [SerializeField] private LayerMask interactionLayer = -1;
    [SerializeField] private float interactionDistance = 10f;
    [SerializeField] private bool requireLineOfSight = true;

    private Camera mainCamera;
    private readonly HashSet<InteractableItem> interactableItems = new HashSet<InteractableItem>();
    private InteractableItem currentHoveredItem;

    private void Awake()
    {
        if (Instance == null)
        {
            Instance = this;
            // DontDestroyOnLoad(gameObject); // 如果需要跨场景使用可以取消注释
        }
        else
        {
            Destroy(gameObject);
        }

        mainCamera = Camera.main;
    }

    private void Update()
    {
        // 每帧只执行一次检测
        CheckAllInteractions();
    }

    // 注册可交互物品
    public void RegisterInteractable(InteractableItem item)
    {
        interactableItems.Add(item);
        Debug.Log(item.gameObject.name + " registered to InteractionManager.");
    }

    // 取消注册可交互物品
    public void UnregisterInteractable(InteractableItem item)
    {
        interactableItems.Remove(item);

        // 如果取消注册的是当前悬停的物品，需要清除悬停状态
        if (currentHoveredItem == item)
        {
            currentHoveredItem?.OnMouseExitItem();
            currentHoveredItem = null;
        }
    }

    // 统一处理所有交互
    private void CheckAllInteractions()
    {
        Ray ray = mainCamera.ScreenPointToRay(Input.mousePosition);
        InteractableItem newHoveredItem = null;

        // 使用 RaycastAll 获取所有可能的交互目标
        RaycastHit[] hits = Physics.RaycastAll(ray, interactionDistance, interactionLayer);

        // 找到最近的可用交互目标
        float closestDistance = float.MaxValue;

        foreach (var hit in hits)
        {
            InteractableItem item = hit.collider.GetComponent<InteractableItem>();
            if (item != null && item.IsInteractable)
            {
                // 检查视线遮挡（如果需要）
                if (requireLineOfSight && !HasLineOfSight(hit.point))
                    continue;

                // 选择最近的目标
                if (hit.distance < closestDistance)
                {
                    closestDistance = hit.distance;
                    newHoveredItem = item;
                }
            }
        }

        // 处理悬停状态变化
        if (currentHoveredItem != newHoveredItem)
        {
            currentHoveredItem?.OnMouseExitItem();
            currentHoveredItem = newHoveredItem;
            currentHoveredItem?.OnMouseEnterItem();
        }

        if (Input.GetMouseButtonDown(0) && currentHoveredItem != null && currentHoveredItem.IsInteractable)
        {
            currentHoveredItem.OnMouseClickItem();
        }
    }

    // 检查目标点是否在视线内
    private bool HasLineOfSight(Vector3 targetPoint)
    {
        Vector3 direction = targetPoint - mainCamera.transform.position;
        float distance = direction.magnitude;

        if (Physics.Raycast(mainCamera.transform.position, direction.normalized,
            out RaycastHit hit, distance, interactionLayer))
        {
            return hit.collider.GetComponent<InteractableItem>() != null;
        }

        return true;
    }

    // 在编辑器中绘制可视化辅助
#if UNITY_EDITOR
    private void OnDrawGizmos()
    {
        if (mainCamera != null && currentHoveredItem != null)
        {
            Gizmos.color = Color.green;
            Gizmos.DrawLine(mainCamera.transform.position, currentHoveredItem.transform.position);
        }
    }
#endif
}
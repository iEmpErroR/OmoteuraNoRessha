using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public class InteractableItemsManager : MonoBehaviour
{
    // 单例实例
    public static InteractableItemsManager Instance { get; private set; }

    // 可交互物品集合 - 使用 HashSet 提高性能
    private HashSet<InteractableItem> interactableItems = new HashSet<InteractableItem>();

    // Start is called before the first frame update
    private void Awake()
    {
        if (Instance == null)
        {
            Instance = this;
            //DontDestroyOnLoad(gameObject); // 如果需要跨场景使用可以取消注释
        }
        else
        {
            Destroy(gameObject);
        }
    }

    // Update is called once per frame
    private void Update()
    {

    }

    #region 公共方法 - 管理物品

    /// <summary>
    /// 注册可交互物品到管理器
    /// </summary>
    public void RegisterInteractable(InteractableItem item)
    {
        if (item != null && interactableItems.Add(item))
        {
            Debug.Log($"[InteractionManager] 注册可交互物品: {item.gameObject.name}");
            item.EnableInteractable();
        }
    }

    /// <summary>
    /// 从管理器移除可交互物品
    /// </summary>
    public void UnregisterInteractable(InteractableItem item)
    {
        if (item != null && interactableItems.Remove(item))
        {
            Debug.Log($"[InteractionManager] 移除可交互物品: {item.gameObject.name}");
        }
    }

    /// <summary>
    /// 清理无效物品引用
    /// </summary>
    public void CleanupInvalidItems()
    {
        int beforeCount = interactableItems.Count;

        // 移除为null或已销毁的物品
        interactableItems.RemoveWhere(item => item == null || item.gameObject == null);

        int removedCount = beforeCount - interactableItems.Count;
        if (removedCount > 0)
        {
            Debug.Log($"[InteractionManager] 清理了 {removedCount} 个无效物品");
        }

        CheckInteractableItemsExistence();
    }

    #endregion

    #region 公共方法 - 全局控制

    /// <summary>
    /// 切换所有物品的交互状态
    /// </summary>
    public void ToggleAllInteractions()
    {
        foreach (var item in interactableItems)
        {
            if (item != null || item.gameObject != null)
            {
                item.ToggleInteractable();
            }
            else // 处理失效物品
            {
                interactableItems.Remove(item);
            }
        }
    }

    #endregion

    #region 私有方法

    /// <summary>
    /// 检查是否存在可交互物品
    /// </summary>
    private bool HasInteractableItems()
    {
        bool hasInteractable = interactableItems.Any(item =>
            item != null && item.IsInteractable);

        return hasInteractable;
    }

    /// <summary>
    /// 检查可交互物品是否存在，如果没有则触发事件
    /// </summary>
    private void CheckInteractableItemsExistence()
    {
        if (!HasInteractableItems())
        {
            Debug.Log("[InteractionManager] 没有可交互物品存在");
            EventManager.TriggerNoInteractableItems();
        }
    }

    #endregion
}
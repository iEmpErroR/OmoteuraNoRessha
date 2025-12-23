using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class EventManager
{
    // 交互事件
    public static event System.Action OnInteract;
    public static void TriggerInteract()
    {
        OnInteract?.Invoke();
    }

    // 无可交互物品事件
    public static event System.Action OnNoInteractableItems;
    public static void TriggerNoInteractableItems()
    {
        OnNoInteractableItems?.Invoke();
    }

    // 时间推进事件
    public static event System.Action OnTimeAdvance;
    public static void TriggerTimeAdvance()
    {
        OnTimeAdvance?.Invoke();
    }
}
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ItemSpawner : MonoBehaviour
{
    // 单例实例
    public static ItemSpawner Instance { get; private set; }

    [System.Serializable]
    public class ItemSpawnInfo
    {
        public GameObject itemPrefab; // 物品预制体
        public Transform spawnPoint; // 生成点（空物体）
    }

    [System.Serializable]
    public class DaySpawnConfig
    {
        public int dayNumber;
        public List<ItemSpawnInfo> spawnInfos = new List<ItemSpawnInfo>(); // 这天的所有物品生成信息
    }

    [Header("天数配置")]
    [SerializeField] private List<DaySpawnConfig> dayConfigs = new List<DaySpawnConfig>();

    private int currentInteractionsInTimeSlot = 0;
    private List<InteractableItem> spawnedItems = new List<InteractableItem>();
    private DaySpawnConfig currentDayConfig;

    private void Awake()
    {
        if (Instance == null)
        {
            Instance = this;
        }
        else
        {
            Destroy(gameObject);
        }
    }

    private void Start()
    {

    }

    /// <summary>
    /// 开始新的一天
    /// </summary>
    public void StartDay(int day)
    {
        currentInteractionsInTimeSlot = 0;

        // 清理之前的物品
        CleanupAllItems();

        // 获取当天的配置
        currentDayConfig = dayConfigs.Find(config => config.dayNumber == day);
        if (currentDayConfig == null)
        {
            Debug.LogError($"[ItemSpawner] 找不到第{day}天的配置");
            return;
        }

        // 生成当天的物品
        SpawnDayItems();

        Debug.Log($"[ItemSpawner] 开始第{day}天，生成{currentDayConfig.spawnInfos.Count}个物品");
    }

    /// <summary>
    /// 生成当天的物品
    /// </summary>
    private void SpawnDayItems()
    {
        if (currentDayConfig == null || currentDayConfig.spawnInfos.Count == 0)
        {
            Debug.LogWarning($"[ItemSpawner] 第{TimeManager.DayCount}天没有可用的物品配置");
            return;
        }

        foreach (var spawnInfo in currentDayConfig.spawnInfos)
        {
            if (spawnInfo.itemPrefab != null && spawnInfo.spawnPoint != null)
            {
                SpawnItem(spawnInfo);
            }
            else
            {
                Debug.LogWarning($"[ItemSpawner] 第{TimeManager.DayCount}天的物品配置中存在空预制体或空生成点");
            }
        }
    }

    /// <summary>
    /// 根据生成信息生成物品
    /// </summary>
    private void SpawnItem(ItemSpawnInfo spawnInfo)
    {
        GameObject newItem = Instantiate(
            spawnInfo.itemPrefab,
            spawnInfo.spawnPoint.position,
            spawnInfo.spawnPoint.rotation
        );

        InteractableItem interactable = newItem.GetComponent<InteractableItem>();

        if (interactable != null)
        {
            spawnedItems.Add(interactable);

            // 自动注册到可交互物品管理器
            if (InteractableItemsManager.Instance != null)
            {
                InteractableItemsManager.Instance.RegisterInteractable(interactable);
            }

            Debug.Log($"[ItemSpawner] 为第{TimeManager.DayCount}天生成了物品: {newItem.name} 在位置: {spawnInfo.spawnPoint.name}");
        }
        else
        {
            Debug.LogWarning($"[ItemSpawner] 生成的物品没有InteractableItem组件: {newItem.name}");
            Destroy(newItem);
        }
    }

    /// <summary>
    /// 清理所有物品
    /// </summary>
    private void CleanupAllItems()
    {
        spawnedItems.Clear();
    }
}
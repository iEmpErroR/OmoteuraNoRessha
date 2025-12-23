using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TimeManager : MonoBehaviour
{
    // 单例实例
    public static TimeManager Instance { get; private set; }

    // 时间段枚举
    public enum TimeOfDay { Morning, Afternoon, Evening };

    // 当前时间段
    private TimeOfDay currentTimeOfDay = TimeOfDay.Morning;
    public TimeOfDay CurrentTimeOfDay
    {
        get
        {
            return currentTimeOfDay;
        }
    }

    // 互动几次才可以推进时间段
    [SerializeField] private int stageDuration = 1;

    // 当前时间段推进的次数
    private int advanceCount = 0;

    // 天数
    public static int DayCount { get; private set; } = 1;

    // Start is called before the first frame update
    void Awake()
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
    void Update()
    {

    }

    #region 时间控制

    // 记录一次时间推进,检查是否达到时间段推进条件
    public void RecordTimeAdvance()
    {
        // 推进计数+1
        advanceCount++;
        Debug.Log($"Time advance recorded. Current count: {advanceCount}/{stageDuration}");

        if (advanceCount >= stageDuration)
        {
            advanceCount = 0; // 重置计数器
            AdvanceToNextTime();
        }
    }

    // 设置特定时间段
    public void SetTime(TimeOfDay time)
    {
        currentTimeOfDay = time;
        Debug.Log("Setting time to " + time.ToString() + ".");

        // 触发时间推进事件
        EventManager.TriggerTimeAdvance();
    }

    // 重置时间
    public void ResetTime()
    {
        // 重置天数和时间段
        DayCount = 1;
        currentTimeOfDay = TimeOfDay.Morning;
        Debug.Log($"Time reset to Day {DayCount}, {currentTimeOfDay}.");

        // 触发时间推进事件
        EventManager.TriggerTimeAdvance();
    }

    // 改变推进时间段所需互动次数
    public void SetStageDuration(int newDuration)
    {
        if (newDuration > 0)
        {
            stageDuration = newDuration;
            Debug.Log($"Stage duration set to {stageDuration} interactions.");
        }
        else
        {
            Debug.LogWarning("Stage duration must be greater than 0;");
        }
    }

    // 推进到下一个时间段
    private void AdvanceToNextTime()
    {
        switch (currentTimeOfDay)
        {
            // 上午 ==> 下午
            case TimeOfDay.Morning:
                currentTimeOfDay = TimeOfDay.Afternoon;
                Debug.Log("Advancing time from Morning to Afternoon.");
                break;

            // 下午 ==> 晚上
            case TimeOfDay.Afternoon:
                currentTimeOfDay = TimeOfDay.Evening;
                Debug.Log("Advancing time from Afternoon to Evening.");
                break;

            // 晚上 ==> 上午 (天数 + 1)
            default:
                currentTimeOfDay = TimeOfDay.Morning;
                DayCount++;
                Debug.Log($"Advancing time from Evening to Morning.\nDay: {DayCount}");
                break;
        }

        // 触发时间推进事件
        EventManager.TriggerTimeAdvance();
    }

    #endregion

    #region 私有方法



    #endregion
}
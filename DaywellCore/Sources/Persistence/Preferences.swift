import DesignSystem
import Domain
import Sharing

public enum Preferences {
    public static var dailyZones: AppStorageKey<[DayZone]>.Default {
        AppStorageKey<[DayZone]>.Default[
            .appStorage(UserDefaultsKeys.dailyZones),
            default: DayZone.defaults
        ]
    }

    public static var appearance: AppStorageKey<DWAppearance>.Default {
        AppStorageKey<DWAppearance>.Default[
            .appStorage(UserDefaultsKeys.appearance),
            default: DWAppearance.defaultValue
        ]
    }

    public static var todayLayout: AppStorageKey<TodayLayout>.Default {
        AppStorageKey<TodayLayout>.Default[
            .appStorage(UserDefaultsKeys.todayLayout),
            default: TodayLayout.defaultValue
        ]
    }

    public static var customCardWidthPercentage: AppStorageKey<Double>.Default {
        AppStorageKey<Double>.Default[
            .appStorage(UserDefaultsKeys.customCardWidthPercentage),
            default: 0.4
        ]
    }

    public static var firstDayOfWeek: AppStorageKey<FirstDayOfWeek>.Default {
        AppStorageKey<FirstDayOfWeek>.Default[
            .appStorage(UserDefaultsKeys.firstDayOfWeek),
            default: FirstDayOfWeek.defaultValue
        ]
    }

    public static var taskDurations: AppStorageKey<[TaskDuration]>.Default {
        AppStorageKey<[TaskDuration]>.Default[
            .appStorage(UserDefaultsKeys.taskDurations),
            default: TaskDuration.defaults
        ]
    }

    public static var defaultTaskDuration: AppStorageKey<TaskDuration>.Default {
        AppStorageKey<TaskDuration>.Default[
            .appStorage(UserDefaultsKeys.defaultTaskDuration),
            default: TaskDuration.defaultValue
        ]
    }

    public static var taskRemindersEnabled: AppStorageKey<Bool>.Default {
        AppStorageKey<Bool>.Default[
            .appStorage(UserDefaultsKeys.taskRemindersEnabled),
            default: true
        ]
    }

    public static var appIconBadgeEnabled: AppStorageKey<Bool>.Default {
        AppStorageKey<Bool>.Default[
            .appStorage(UserDefaultsKeys.appIconBadgeEnabled),
            default: true
        ]
    }
}

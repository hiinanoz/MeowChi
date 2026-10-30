import Foundation
import UserNotifications

/// Optional, gentle reminders: at most one pending notification, never at night, never guilt-tripping.
@MainActor
enum Reminders {
    /// Quiet hours: nothing is delivered from 21:00 to 09:00 (local time).
    static let quietStartHour = 21
    static let quietEndHour = 9
    /// A need below this in the forecast is worth a reminder.
    static let needThreshold = 25.0

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// When the forecast says the cat will want care, moved out of quiet hours. nil = no reminder needed.
    static func nextReminderDate(_ snapshot: WidgetSnapshot, now: Date, calendar: Calendar = .current) -> Date? {
        guard let point = snapshot.points.first(where: {
            $0.date > now.addingTimeInterval(1800) && !$0.sleeping &&
                min($0.hunger, $0.energy, $0.happiness, $0.cleanliness) < needThreshold
        }) else { return nil }
        let hour = calendar.component(.hour, from: point.date)
        guard hour >= quietStartHour || hour < quietEndHour else { return point.date }
        // Move to 09:00 on the same morning (or the next morning if it's late evening).
        var day = calendar.startOfDay(for: point.date)
        if hour >= quietStartHour { day = calendar.date(byAdding: .day, value: 1, to: day) ?? day }
        return calendar.date(bySettingHour: quietEndHour, minute: 0, second: 0, of: day)
    }

    /// Replaces any pending reminder with the next useful one. Call when the app goes to the background.
    static func reschedule(from store: GameStore) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard store.state.settings.remindersEnabled else { return }
        let snapshot = WidgetBridge.makeSnapshot(from: store.state, now: .now, balance: store.balance)
        guard let date = nextReminderDate(snapshot, now: .now) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Meowchi"
        content.body = String(localized: "notify.care \(store.state.cat.name)")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, date.timeIntervalSinceNow), repeats: false)
        center.add(UNNotificationRequest(identifier: "meowchi.care", content: content, trigger: trigger))
    }
}

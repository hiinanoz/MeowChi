import SwiftUI

@MainActor
struct TasksView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let daily = store.state.daily
        let claimed = daily.tasks.filter(\.claimed).count
        SheetScaffold(title: "tasks.title", onClose: { dismiss() }) {
            ForEach(daily.tasks) { task in
                if let definition = store.definition(for: task) { row(task, definition) }
            }
            VStack(spacing: 8) {
                HStack {
                    Text("tasks.bonus \(store.balance.allTasksBonusCoins)").font(PixelFont.body(12))
                    Spacer()
                    Text(verbatim: "\(claimed)/\(daily.tasks.count)").font(PixelFont.body(12)).monospacedDigit()
                }
                PixelBar(value: daily.tasks.isEmpty ? 0 : Double(claimed) / Double(daily.tasks.count) * 100,
                         color: PixelPalette.warn, segments: max(1, daily.tasks.count))
                if daily.bonusClaimed {
                    Text("tasks.claimed").font(PixelFont.body(11)).foregroundStyle(PixelPalette.accentShade)
                } else {
                    Button("tasks.claim") { if store.claimDailyBonus() == .ok { AudioManager.shared.play(.levelUp) } }
                        .buttonStyle(PixelButtonStyle(fill: PixelPalette.warn))
                        .disabled(!daily.allClaimed)
                }
            }
            .padding(10)
            .background(PixelBorder().fill(PixelPalette.panelShade))
            Text("tasks.resetHint").font(PixelFont.body(9)).foregroundStyle(PixelPalette.accentShade)
        }
    }

    private func row(_ task: DailyTaskProgress, _ definition: DailyTaskDefinition) -> some View {
        let done = task.progress >= definition.target
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(definition.titleKey).font(PixelFont.body(12))
                HStack(spacing: 6) {
                    PixelBar(value: Double(task.progress) / Double(definition.target) * 100, color: PixelPalette.xp,
                             segments: max(1, definition.target))
                        .frame(maxWidth: 90)
                    Text(verbatim: "\(task.progress)/\(definition.target)").font(PixelFont.body(10)).monospacedDigit()
                }
            }
            Spacer()
            if task.claimed {
                Text("tasks.claimed").font(PixelFont.body(10)).foregroundStyle(PixelPalette.good)
            } else {
                Button { if store.claimTask(task.id) == .ok { AudioManager.shared.play(.coin) } } label: {
                    HStack(spacing: 4) {
                        PixelIcon(name: "icon_coin", size: 14)
                        Text(definition.coins, format: .number)
                    }
                    .padding(.horizontal, 8)
                }
                .buttonStyle(PixelButtonStyle(fill: done ? PixelPalette.warn : PixelPalette.barTrack))
                .fixedSize()
                .disabled(!done)
            }
        }
        .padding(8)
        .background(PixelBorder().fill(PixelPalette.panelShade))
    }
}

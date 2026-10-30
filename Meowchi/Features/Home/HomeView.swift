import SpriteKit
import SwiftUI

/// Main screen: HUD on top, the SpriteKit room in the middle, the action bar at the bottom.
@MainActor
struct HomeView: View {
    var onMainMenu: @MainActor () -> Void = {}
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene = RoomScene(size: CGSize(width: 390, height: 500))
    @State private var notice: LocalizedStringResource?
    @State private var noticeID = 0
    /// Black "door" shown while switching between the room and an immersive screen.
    @State private var curtain = false

    @State private var panel: CarePanel?
    @State private var isBrushing = false
    @State private var showShop = false
    @State private var showTasks = false
    @State private var showDecor = false
    @State private var showSettings = false
    @State private var showNails = false
    @State private var showCozy = false
    @State private var chooseChannel = false
    @State private var showLogin = false
    @State private var showCollection = false
    @State private var showMenu = false
    @State private var flash = false
    @State private var activeGame: MiniGameKind?
    @State private var walkLocation: WalkLocation?
    @State private var showWalkPicker = false

    var body: some View {
        presentations(layoutBody)
    }

    private var layoutBody: some View {
        GeometryReader { geo in
            layoutContent
                .onAppear { updateLayout(geo.size) }
                .onChange(of: geo.size) { _, size in updateLayout(size) }
        }
    }

    private var layoutContent: some View {
        Group {
            if wide {
                // iPad / wide windows: big room on the left, controls in a side column.
                HStack(alignment: .top, spacing: 12) {
                    roomView
                    VStack(spacing: 10) {
                        hud
                        if isBrushing { brushBanner }
                        ScrollView { panelStack }
                        Spacer(minLength: 0)
                        ActionBar(panel: $panel, onToggleSleep: toggleSleep)
                    }
                    .frame(width: 380)
                }
            } else {
                VStack(spacing: 8) {
                    hud
                    roomView.overlay(alignment: .bottom) {
                        VStack(spacing: 0) {
                            if isBrushing { brushBanner } else { TutorialBanner() }
                            panelStack.padding(8)
                        }
                        .animation(.easeOut(duration: 0.2), value: panel)
                    }
                    ActionBar(panel: $panel, onToggleSleep: toggleSleep)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(PixelPalette.frame.ignoresSafeArea())
        .onAppear {
            AudioManager.shared.context = .home
            scene.store = store
            #if DEBUG
            // Screenshot/QA helper: `-openScreen shop|tasks|laser|food|clean|health`.
            if let i = CommandLine.arguments.firstIndex(of: "-openScreen"), i + 1 < CommandLine.arguments.count {
                switch CommandLine.arguments[i + 1] {
                case "shop": showShop = true
                case "tasks": showTasks = true
                case "decor": showDecor = true
                case "settings": showSettings = true
                case "nails": showNails = true
                case "login": showLogin = true
                case "collection": showCollection = true
                case "menu": showMenu = true
                case "cozy": showCozy = true
                case "tv": DispatchQueue.main.asyncAfter(deadline: .now() + 1) { watch("fish") }
                case "friend": DispatchQueue.main.asyncAfter(deadline: .now() + 1) { inviteFriend() }
                case "laser": activeGame = .laserChase
                case "garden": walkLocation = .garden
                case "walks": showWalkPicker = true
                case "beach": walkLocation = .beach
                case "play": panel = .play
                case "food": panel = .food
                case "clean": panel = .clean
                case "health": panel = .health
                default: break
                }
            }
            #endif
        }
        .onChange(of: store.state.cat.isSleeping) { _, sleeping in
            if sleeping { setBrushing(false) }
            scene.setSleeping(sleeping, animated: true)
        }
        .onChange(of: store.isLitterDirty) { _, _ in scene.refreshLitter() }
        .onChange(of: store.attention) { _, _ in scene.refreshAttention() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.tick()
                AudioManager.shared.resumeMusic()
            } else if phase == .background {
                store.save()
                AudioManager.shared.pauseMusic()
                WidgetBridge.update(from: store)
                Reminders.reschedule(from: store)
            }
        }
        .onChange(of: panel) { _, open in scene.setPanelOpen(open != nil) }
        .onChange(of: store.levelUpCount) { _, _ in
            AudioManager.shared.play(.levelUp)
            show("notice.levelUp", important: true)
        }
        .task {
            // Foreground refresh. Offline time is handled by elapsed-time simulation, not timers.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                store.tick()
            }
        }
    }

    /// Sheets, covers and dialogs, split out so the type checker stays fast.
    private func presentations<V: View>(_ content: V) -> some View {
        content
        .sheet(isPresented: $showShop) { ShopView().environment(store) }
        .sheet(isPresented: $showTasks) { TasksView().environment(store) }
        .sheet(isPresented: $showDecor) { DecorView().environment(store) }
        .sheet(isPresented: $showSettings) { SettingsView().environment(store) }
        .sheet(isPresented: $showNails) { NailTrimView().environment(store) }
        .fullScreenCover(isPresented: $showCozy, onDismiss: liftCurtain) { CozyView().environment(store) }
        .overlay { if curtain { Color.black.ignoresSafeArea().allowsHitTesting(false).transition(.opacity) } }
        .sensoryFeedback(.success, trigger: store.levelUpCount)
        .sensoryFeedback(.success, trigger: store.state.badges.count)
        .sheet(isPresented: $showLogin) { LoginRewardView().environment(store) }
        .sheet(isPresented: $showCollection) { CollectionView().environment(store) }
        .sheet(isPresented: $showMenu) {
            GameMenuView { destination in
                switch destination {
                case .shop: showShop = true
                case .decor: showDecor = true
                case .collection: showCollection = true
                case .tasks: showTasks = true
                case .checkIn: showLogin = true
                case .settings: showSettings = true
                case .mainMenu: setBrushing(false); onMainMenu()
                }
            }
            .environment(store)
        }
        .onChange(of: store.lastUnlockedBadge) { _, badge in
            guard badge != nil else { return }
            AudioManager.shared.play(.levelUp)
            show("notice.badge", important: true)
        }
        .task {
            // Greet with the daily check-in once the room has settled (not during onboarding hints).
            try? await Task.sleep(for: .seconds(0.8))
            #if DEBUG
            if CommandLine.arguments.contains("-openScreen") { return }
            #endif
            if store.showWelcomeBack {
                store.showWelcomeBack = false
                show("notice.welcomeBack \(store.state.cat.name)", important: true)
                try? await Task.sleep(for: .seconds(2.5))
            }
            if store.canClaimLogin, store.tutorialStep == nil { showLogin = true }
        }
        .confirmationDialog("tv.watch", isPresented: $chooseChannel, titleVisibility: .visible) {
            Button("tv.fish") { watch("fish") }
            Button("tv.birds") { watch("birds") }
            Button("common.cancel", role: .cancel) {}
        }
        .onChange(of: store.isWaterLow) { _, _ in scene.refreshWater() }
        .onChange(of: store.state.decor) { _, _ in scene.applyDecor() }
        .onChange(of: store.state.cat.look) { _, _ in scene.applyDecor() }
        .fullScreenCover(item: $activeGame, onDismiss: liftCurtain) {
            MiniGameView(kind: $0).environment(store).onAppear { AudioManager.shared.context = .game }
        }
        .sheet(isPresented: $showWalkPicker) {
            WalkPickerView { location in
                showWalkPicker = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { presentImmersive { walkLocation = location } }
            }
            .environment(store)
        }
        .fullScreenCover(item: $walkLocation, onDismiss: liftCurtain) { location in
            GardenView(location: location).environment(store).onAppear { AudioManager.shared.context = .game }
        }
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Side-by-side layout for regular-width landscape (iPad). Portrait iPads stack, which gives the room a 2x scale.
    @State private var wide = false

    private func updateLayout(_ size: CGSize) {
        wide = sizeClass == .regular && size.width > size.height
    }

    private var hud: some View {
        HUDView(onShop: { panel = nil; showShop = true }, onTasks: { panel = nil; showTasks = true },
                    onMenu: { panel = nil; showMenu = true })
    }

    private var roomView: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .clipShape(PixelBorder(step: 4))
                .overlay(PixelBorder(step: 4).stroke(PixelPalette.ink, lineWidth: 2))
                .overlay(alignment: .top) { noticeBanner }
                .accessibilityElement()
                .accessibilityLabel(Text(verbatim: store.state.cat.name) + Text(verbatim: ", ") + Text(store.mood.titleKey))
                .accessibilityHint(Text("a11y.room.hint"))
                .accessibilityAction(named: Text(isBrushing ? "a11y.brush" : "a11y.pet")) { scene.accessibilityPet() }
                .accessibilityAction(named: Text("collection.takePhoto")) { takePhoto() }
                .accessibilityAction(named: Text("a11y.scratch")) { scene.goScratch() }
                .overlay { if flash { Color.white.allowsHitTesting(false).transition(.opacity) } }
                .overlay(alignment: .topLeading) {
                    Button(action: { takePhoto() }) {
                        PixelIcon(name: "icon_camera", size: 22).padding(6).pixelPanel()
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel(Text("collection.takePhoto"))
                }
            .overlay(alignment: .bottom) { if wide { TutorialBanner() } }
    }

    /// The open care panel with its close button.
    private var panelStack: some View {
        panelView
            .overlay(alignment: .topTrailing) {
                if panel != nil {
                    Button { withAnimation(.easeOut(duration: 0.2)) { panel = nil } } label: {
                        PixelIcon(name: "icon_close", size: 14).padding(15)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("common.close"))
                }
            }
    }

    @ViewBuilder private var noticeBanner: some View {
        if let notice {
            Text(notice)
                .font(PixelFont.body(12))
                .foregroundStyle(PixelPalette.ink)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .pixelPanel()
                .padding(.top, 8)
                .transition(.banner)
        }
    }

    @ViewBuilder private var panelView: some View {
        switch panel {
        case .food:
            FoodPanel(onPick: { food in run(store.feed(food.id), noReward: nil) { scene.playFeeding() } },
                      onWater: { run(store.changeWater(), noReward: "notice.waterFresh") {
                          AudioManager.shared.play(.tap)
                          scene.refreshWater(drink: true)
                      } })
                .transition(.panel)
        case .clean:
            CleanPanel(
                onBath: { run(store.bathe(), noReward: "notice.alreadyClean") { scene.playBath() } },
                onBrush: { panel = nil; setBrushing(true) },
                onNails: {
                    if store.state.cat.isSleeping { return show("notice.sleeping") }
                    if !store.canTrimNails { return show("notice.nailsNeat") }
                    panel = nil
                    showNails = true
                },
                onLitter: { run(store.cleanLitter(), noReward: "notice.litterClean") { scene.refreshLitter(sparkle: true) } }
            )
            .transition(.panel)
        case .play:
            PlayPanel(onCozy: { startActivity { presentImmersive { showCozy = true } } },
                      onTV: { chooseChannel = true },
                      onFriend: inviteFriend,
                      onLaser: { startActivity { presentImmersive { activeGame = .laserChase } } },
                      onGarden: { startActivity { showWalkPicker = true } })
                .transition(.panel)
        case .health:
            HealthPanel { run(store.visitVet(), noReward: "notice.healthy") { scene.playVet() } }
                .transition(.panel)
        case nil:
            EmptyView()
        }
    }

    private var brushBanner: some View {
        HStack(spacing: 10) {
            PixelIcon(name: "icon_brush", size: 18)
            Text("brush.hint \(store.state.cat.name)")
                .font(PixelFont.body(12))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("brush.done") { setBrushing(false) }
                .font(PixelFont.body(12))
                .foregroundStyle(PixelPalette.accentShade)
        }
        .foregroundStyle(PixelPalette.ink)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .pixelPanel()
        .padding(8)
    }

    /// Runs an action result: success closes the panel and plays the scene part; anything else shows why.
    private func run(_ result: ActionResult, noReward: LocalizedStringResource?, onSuccess: () -> Void) {
        switch result {
        case .ok:
            panel = nil
            onSuccess()
        case .busy: show("notice.busy")
        case .sleeping: show("notice.sleeping")
        case .outOfStock: show("notice.noFood")
        case .tooSoon: show("notice.tooSoon")
        case .insufficientCoins: show("notice.noCoins")
        case .tooTired: show("notice.tooTired")
        case .locked, .alreadyOwned: break
        case .noReward: if let noReward { show(noReward) }
        case .unknownItem: break
        }
    }

    private func setBrushing(_ on: Bool) {
        isBrushing = on
        scene.isBrushing = on
    }

    private func takePhoto() {
        guard let image = scene.snapshot(), PhotoAlbum.save(image) != nil else { return }
        store.recordPhoto()
        AudioManager.shared.play(.tap)
        if !Motion.reduced {
            withAnimation(.easeOut(duration: 0.08)) { flash = true }
            withAnimation(.easeIn(duration: 0.4).delay(0.08)) { flash = false }
        }
        show("notice.photoSaved")
    }

    private func watch(_ channel: String) {
        run(store.watchTV(), noReward: nil) {
            scene.playTV(channel: channel)
            if !store.hasSeenTip("tv") {
                store.markTipSeen("tv")
                show("tip.tv", important: true)
            }
        }
    }

    private func inviteFriend() {
        let (result, friend) = store.inviteFriend()
        run(result, noReward: nil) {
            guard let friend else { return }
            scene.playFriendVisit(look: friend.look)
            show("friend.arrived \(friend.name)")
        }
    }

    private func startActivity(_ open: () -> Void) {
        panel = nil
        setBrushing(false)
        if store.state.cat.isSleeping { return show("notice.sleeping") }
        open()
    }

    private func toggleSleep() {
        panel = nil
        if store.setSleeping(!store.state.cat.isSleeping) == .busy { show("notice.busy") }
    }

    /// Shows a banner and reads it out for VoiceOver. Important news stays a little longer.
    private func show(_ text: LocalizedStringResource, important: Bool = false) {
        noticeID += 1
        let id = noticeID
        withAnimation { notice = text }
        AccessibilityNotification.Announcement(String(localized: text)).post()
        Task {
            try? await Task.sleep(for: .seconds(important ? 3.5 : 2))
            if noticeID == id { withAnimation { notice = nil } }
        }
    }

    /// Fades the room to black, then presents the immersive screen without its slide (a "door" transition).
    private func presentImmersive(_ present: @escaping () -> Void) {
        guard !Motion.reduced else { return present() }
        withAnimation(.easeIn(duration: 0.25)) { curtain = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { present() }
        }
    }

    private func liftCurtain() {
        AudioManager.shared.context = .home
        withAnimation(.easeOut(duration: 0.35)) { curtain = false }
    }
}

private struct ActionBar: View {
    @Environment(GameStore.self) private var store
    @Binding var panel: CarePanel?
    let onToggleSleep: @MainActor () -> Void

    var body: some View {
        let sleeping = store.state.cat.isSleeping
        HStack(spacing: 6) {
            ActionButton(icon: "icon_hunger", title: "action.feed", selected: panel == .food) { toggle(.food) }
                .disabled(sleeping)
            ActionButton(icon: "icon_clean", title: "action.clean", selected: panel == .clean) { toggle(.clean) }
            ActionButton(icon: "icon_play", title: "action.play", selected: panel == .play,
                         fill: Color(red: 0.98, green: 0.70, blue: 0.78)) { toggle(.play) }
                .disabled(sleeping)
            ActionButton(icon: "icon_energy", title: sleeping ? "action.wake" : "action.sleep", selected: false,
                         fill: Color(red: 0.62, green: 0.74, blue: 0.98)) { onToggleSleep() }
            ActionButton(icon: "icon_health", title: "action.health", selected: panel == .health) { toggle(.health) }
        }
        .padding(.bottom, 3)
    }

    private func toggle(_ target: CarePanel) {
        withAnimation(.easeOut(duration: 0.2)) { panel = panel == target ? nil : target }
    }
}

private struct ActionButton: View {
    let icon: String
    let title: LocalizedStringKey
    let selected: Bool
    var fill = PixelPalette.accent
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: { AudioManager.shared.play(.tap); action() }) {
            VStack(spacing: 3) {
                PixelIcon(name: icon, size: 20)
                Text(title).font(PixelFont.body(10)).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(PixelButtonStyle(fill: selected ? PixelPalette.warn : fill))
    }
}

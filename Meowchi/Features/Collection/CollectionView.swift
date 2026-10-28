import SwiftUI

/// Badges and the photo album.
@MainActor
struct CollectionView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var tab = Tab.badges
    @State private var photos: [URL] = []
    @State private var selected: URL?

    enum Tab { case badges, photos }

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        SheetScaffold(title: "collection.title", onClose: { dismiss() }) {
            HStack(spacing: 6) {
                chip(.badges, "collection.badges \(store.state.badges.count) \(Badge.all.count)")
                chip(.photos, "collection.photos \(photos.count)")
                Spacer()
            }
            switch tab {
            case .badges:
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Badge.all) { badgeCell($0) }
                }
            case .photos:
                if photos.isEmpty {
                    Text("collection.noPhotos").font(PixelFont.body(12)).multilineTextAlignment(.center).padding(20)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                        ForEach(photos, id: \.self) { url in
                            Button { selected = url } label: { thumbnail(url) }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear { photos = PhotoAlbum.all() }
        .sheet(item: $selected) { url in
            PhotoDetailView(url: url) {
                PhotoAlbum.delete(url)
                photos = PhotoAlbum.all()
                selected = nil
            }
        }
    }

    private func chip(_ target: Tab, _ title: LocalizedStringKey) -> some View {
        Button { tab = target } label: {
            Text(title).font(PixelFont.body(11)).padding(.horizontal, 10).padding(.vertical, 6)
                .background(PixelBorder().fill(tab == target ? PixelPalette.warn : PixelPalette.panelShade))
                .overlay(PixelBorder().stroke(PixelPalette.ink, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func badgeCell(_ badge: Badge) -> some View {
        let unlocked = store.state.badges[badge.id] != nil
        let progress = min(store.progress(of: badge), badge.target)
        return VStack(spacing: 4) {
            PixelIcon(name: unlocked ? badge.icon : "icon_badge_locked", size: 32)
            Text(badge.nameKey).font(PixelFont.body(10)).multilineTextAlignment(.center).lineLimit(2)
            Text(badge.detailKey).font(PixelFont.body(8)).multilineTextAlignment(.center).lineLimit(2)
                .foregroundStyle(PixelPalette.accentShade)
            if unlocked {
                Text("tasks.claimed").font(PixelFont.body(9)).foregroundStyle(PixelPalette.good)
            } else {
                Text(verbatim: "\(progress)/\(badge.target)").font(PixelFont.body(9)).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(6)
        .background(PixelBorder().fill(unlocked ? PixelPalette.warn.opacity(0.35) : PixelPalette.panelShade))
        .accessibilityElement(children: .combine)
    }

    private func thumbnail(_ url: URL) -> some View {
        Group {
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).interpolation(.none).resizable().scaledToFill()
            } else {
                PixelPalette.panelShade
            }
        }
        .frame(height: 140)
        .clipped()
        .overlay(PixelBorder(step: 2).stroke(PixelPalette.ink, lineWidth: 1.5))
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

@MainActor
private struct PhotoDetailView: View {
    let url: URL
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        SheetScaffold(title: "collection.photo", onClose: { dismiss() }) {
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                    .overlay(PixelBorder(step: 2).stroke(PixelPalette.ink, lineWidth: 2))
                HStack(spacing: 10) {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview(Text(verbatim: "Meowchi"), image: Image(uiImage: image))) {
                        Label { Text("collection.share") } icon: { PixelIcon(name: "icon_camera", size: 16) }
                    }
                    .buttonStyle(PixelButtonStyle(fill: PixelPalette.good))
                    Button("collection.delete", role: .destructive) { confirmDelete = true }
                        .buttonStyle(PixelButtonStyle(fill: PixelPalette.bad))
                }
            }
        }
        .confirmationDialog("collection.delete.confirm", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("collection.delete", role: .destructive) { onDelete() }
            Button("common.cancel", role: .cancel) {}
        }
    }
}

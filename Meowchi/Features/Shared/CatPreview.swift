import SpriteKit
import SwiftUI

/// Live, animated cat for SwiftUI screens (HUD avatar, onboarding, customization).
/// Uses the real `CatNode`, so the coat shader, ears and tail match the game exactly.
struct CatPreview: View {
    let look: CatLook
    /// Use a multiple of 64 so art pixels stay square and sharp.
    var size: CGFloat = 128
    var animation: CatAnimation = .idle
    var mood: TailMood = .happy
    @State private var scene = CatPreviewScene()

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 15, options: [.allowsTransparency])
            .frame(width: size, height: size)
            .onAppear { scene.configure(look: look, animation: animation, mood: mood) }
            .onChange(of: look) { _, new in scene.configure(look: new, animation: animation, mood: mood) }
            .accessibilityHidden(true)
    }
}

final class CatPreviewScene: SKScene {
    private let cat = CatNode()

    override init(size: CGSize) {
        super.init(size: CatNode.frameSize)
        scaleMode = .aspectFit
        backgroundColor = .clear
        cat.position = CGPoint(x: CatNode.frameSize.width / 2, y: 0)
        addChild(cat)
    }

    override convenience init() { self.init(size: CatNode.frameSize) }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        view.backgroundColor = .clear
    }

    func configure(look: CatLook, animation: CatAnimation, mood: TailMood) {
        cat.look = look
        cat.play(animation)
        cat.setTailMood(mood)
    }
}

/// Coat, ear and tail pickers with a live preview. Shared by onboarding and the Decorate sheet.
@MainActor
struct CatCustomizer: View {
    @Binding var look: CatLook
    var previewSize: CGFloat = 128

    var body: some View {
        VStack(spacing: 12) {
            CatPreview(look: look, size: previewSize)
            optionRow("customize.coat") {
                ForEach(CatCoat.allCases) { coat in
                    Button { look.coat = coat.rawValue } label: {
                        Rectangle().fill(coat.swatch)
                            .frame(width: 28, height: 28)
                            .overlay(Rectangle().stroke(PixelPalette.ink, lineWidth: look.coatValue == coat ? 3 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(coat.nameKey))
                    .accessibilityAddTraits(look.coatValue == coat ? .isSelected : [])
                }
            }
            optionRow("customize.ears") {
                ForEach(EarStyle.allCases) { style in
                    choice(style.nameKey, selected: look.earsValue == style) { look.ears = style.rawValue }
                }
            }
            optionRow("customize.tail") {
                ForEach(TailLength.allCases) { length in
                    choice(length.nameKey, selected: look.tailValue == length) { look.tail = length.rawValue }
                }
            }
        }
    }

    private func optionRow<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(PixelFont.body(11))
            HStack(spacing: 6, content: content)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choice(_ title: LocalizedStringKey, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(PixelFont.body(11)).lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(PixelBorder().fill(selected ? PixelPalette.warn : PixelPalette.panelShade))
                .overlay(PixelBorder().stroke(PixelPalette.ink, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

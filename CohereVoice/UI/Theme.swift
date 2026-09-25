import SwiftUI
#if os(macOS)
import AppKit
#endif

enum CVColor {
    static let canvas = Color(red: 247 / 255, green: 247 / 255, blue: 246 / 255)
    static let surface = Color.white
    static let sunken = Color(red: 241 / 255, green: 241 / 255, blue: 239 / 255)
    static let border = Color(red: 231 / 255, green: 231 / 255, blue: 228 / 255)
    static let ink = Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
    static let textSecondary = Color(red: 94 / 255, green: 94 / 255, blue: 90 / 255)
    static let textTertiary = Color(red: 154 / 255, green: 154 / 255, blue: 149 / 255)
    static let live = Color(red: 229 / 255, green: 72 / 255, blue: 77 / 255)
    static let success = Color(red: 48 / 255, green: 164 / 255, blue: 108 / 255)
    static let warning = Color(red: 247 / 255, green: 107 / 255, blue: 21 / 255)
    static let chipSuccess = Color(red: 234 / 255, green: 246 / 255, blue: 239 / 255)
    static let chipSuccessText = Color(red: 30 / 255, green: 122 / 255, blue: 77 / 255)
    static let chipWarning = Color(red: 254 / 255, green: 240 / 255, blue: 230 / 255)
    static let chipWarningText = Color(red: 181 / 255, green: 83 / 255, blue: 14 / 255)
    static let liveFill = Color(red: 253 / 255, green: 236 / 255, blue: 236 / 255)
    static let liveBorder = Color(red: 246 / 255, green: 201 / 255, blue: 202 / 255)
    static let liveText = Color(red: 180 / 255, green: 35 / 255, blue: 24 / 255)
    static let hud = Color(red: 22 / 255, green: 22 / 255, blue: 22 / 255)
}

enum CVRadius {
    static let key: CGFloat = 6
    static let control: CGFloat = 10
    static let card: CGFloat = 14
    static let panel: CGFloat = 20
}

enum CVFont {
    static let windowTitle = Font.system(size: 22, weight: .semibold)
    static let section = Font.system(size: 18, weight: .semibold)
    static let body = Font.system(size: 15)
    static let row = Font.system(size: 14)
    static let secondary = Font.system(size: 13)
    static let label = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 12, weight: .medium)
    static let mono = Font.system(size: 13, design: .monospaced)
}

struct StatusChip: View {
    var title: String
    var granted: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(granted ? CVColor.success : CVColor.warning)
                .frame(width: 6, height: 6)
            Text(title)
                .font(CVFont.caption)
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .foregroundStyle(granted ? CVColor.chipSuccessText : CVColor.chipWarningText)
        .background(granted ? CVColor.chipSuccess : CVColor.chipWarning, in: Capsule())
    }
}

struct TranscriptBox: View {
    var title: String
    var text: String
    var maxHeight: CGFloat = 160

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CVColor.ink)
            ScrollView {
                Text(text)
                    .font(CVFont.body)
                    .foregroundStyle(CVColor.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(key: TranscriptHeightKey.self, value: proxy.size.height)
                        }
                    }
            }
            .scrollDisabled(contentHeight <= maxHeight)
            .frame(height: contentHeight == 0 ? nil : min(contentHeight, maxHeight))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CVColor.sunken, in: RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous))
            .onPreferenceChange(TranscriptHeightKey.self) { contentHeight = $0 }
        }
    }
}

private struct TranscriptHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct GroupedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(CVColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous)
                .stroke(CVColor.border, lineWidth: 1)
        )
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(CVColor.sunken)
            .frame(height: 1)
    }
}

struct InkButtonStyle: ButtonStyle {
    enum Kind {
        case standard
        case prominent
        case live
    }

    var kind: Kind = .standard

    func makeBody(configuration: Configuration) -> some View {
        InkButtonBody(configuration: configuration, kind: kind)
    }
}

private struct InkButtonBody: View {
    let configuration: ButtonStyleConfiguration
    var kind: InkButtonStyle.Kind
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.system(size: isProminent ? 15 : 13, weight: isProminent ? .semibold : .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, isProminent ? 16 : 14)
            .frame(maxWidth: isProminent ? .infinity : nil)
            .frame(height: isProminent ? 48 : 36)
            .background(background, in: RoundedRectangle(cornerRadius: isProminent ? 12 : CVRadius.control, style: .continuous))
            .overlay {
                if showsBorder {
                    RoundedRectangle(cornerRadius: isProminent ? 12 : CVRadius.control, style: .continuous)
                        .stroke(border, lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .focusEffectDisabled()
            .modifier(MacFocusRing())
    }

    private var isProminent: Bool {
        kind == .prominent || kind == .live
    }

    private var foreground: Color {
        guard isEnabled else { return CVColor.textTertiary }
        switch kind {
        case .standard, .prominent: return .white
        case .live: return CVColor.liveText
        }
    }

    private var background: Color {
        guard isEnabled else { return CVColor.sunken }
        switch kind {
        case .standard, .prominent: return CVColor.ink
        case .live: return CVColor.liveFill
        }
    }

    private var showsBorder: Bool {
        kind == .live && isEnabled
    }

    private var border: Color {
        CVColor.liveBorder
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SecondaryButtonBody(configuration: configuration)
    }
}

private struct SecondaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(CVFont.label)
            .foregroundStyle(isEnabled ? CVColor.ink : CVColor.textTertiary)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(isEnabled ? CVColor.surface : CVColor.sunken, in: RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous)
                    .stroke(CVColor.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .focusEffectDisabled()
            .modifier(MacFocusRing())
    }
}

struct TintedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CVFont.label)
            .foregroundStyle(CVColor.ink)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(CVColor.sunken, in: RoundedRectangle(cornerRadius: CVRadius.control, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .focusEffectDisabled()
            .modifier(MacFocusRing())
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CVFont.label)
            .foregroundStyle(CVColor.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .focusEffectDisabled()
            .modifier(MacFocusRing())
    }
}

struct InkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 12)
            Capsule()
                .fill(configuration.isOn ? CVColor.ink : CVColor.border)
                .frame(width: 36, height: 22)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(CVColor.surface)
                        .frame(width: 18, height: 18)
                        .padding(2)
                        .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                }
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}

struct MacFocusRing: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.background(FocusRingDisabler())
        #else
        content
        #endif
    }
}

#if os(macOS)
struct FocusRingDisabler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        FocusRingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? FocusRingView)?.clear()
    }
}

private final class FocusRingView: NSView {
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        DispatchQueue.main.async { [weak self] in
            self?.clear()
        }
    }

    func clear() {
        var view: NSView? = self
        while let current = view {
            current.focusRingType = .none
            view = current.superview
        }
    }
}
#endif

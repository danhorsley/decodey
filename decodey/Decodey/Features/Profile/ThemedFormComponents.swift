import SwiftUI

// MARK: - Themed Form Style
struct ThemedFormStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            content
                .scrollContentBackground(.hidden)
                .background(
                    colorScheme == .dark ?
                        Color.black.opacity(0.95) :
                        Color(hex: "FAFAF8")
                )
        } else {
            content
                .background(
                    colorScheme == .dark ?
                        Color.black.opacity(0.95) :
                        Color(hex: "FAFAF8")
                )
        }
    }
}

extension View {
    func themedFormStyle() -> some View {
        modifier(ThemedFormStyle())
    }
}

// MARK: - Themed Section Header
struct ThemedSectionHeader: View {
    let text: String
    let icon: String?
    
    @Environment(\.colorScheme) var colorScheme
    private let terminalGreen = Color(hex: "4cc9f0")
    
    init(_ text: String, icon: String? = nil) {
        self.text = text
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            Text(text)
                .font(headerFont)
                .foregroundColor(textColor)
                .tracking(colorScheme == .dark ? 1.5 : 0.5)
            
            Spacer()
        }
        .padding(.bottom, 4)
    }
    
    private var headerFont: Font {
        if colorScheme == .dark {
            return .system(size: 12, weight: .medium, design: .monospaced)
        } else {
            return .custom("American Typewriter", size: 13).weight(.semibold)
        }
    }
    
    private var textColor: Color {
        colorScheme == .dark ? terminalGreen.opacity(0.8) : Color.black.opacity(0.6)
    }
    
    private var iconColor: Color {
        colorScheme == .dark ? terminalGreen : Color.black.opacity(0.5)
    }
}

// MARK: - Themed List Row
struct ThemedListRow<Content: View>: View {
    let content: Content
    let isButton: Bool
    
    @Environment(\.colorScheme) var colorScheme
    private let terminalGreen = Color(hex: "4cc9f0")
    
    init(isButton: Bool = false, @ViewBuilder content: () -> Content) {
        self.isButton = isButton
        self.content = content()
    }
    
    var body: some View {
        #if os(iOS)
        content
            .listRowBackground(rowBackground)
            .listRowSeparatorTint(separatorColor)
        #else
        content
            .listRowBackground(rowBackground)
            // No separator tint on older macOS
        #endif
    }
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: colorScheme == .dark ? 0.5 : 0)
            )
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
    }
    
    private var backgroundColor: Color {
        if colorScheme == .dark {
            return isButton ? Color.white.opacity(0.05) : Color.white.opacity(0.03)
        } else {
            return Color.white
        }
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? terminalGreen.opacity(0.1) : Color.clear
    }
    
    private var separatorColor: Color {
        colorScheme == .dark ? terminalGreen.opacity(0.2) : Color.black.opacity(0.1)
    }
}

// MARK: - Themed Toggle Style
struct ThemedToggleStyle: ToggleStyle {
    @Environment(\.colorScheme) var colorScheme
    private let terminalGreen = Color(hex: "4cc9f0")
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .foregroundColor(labelColor)
            
            Spacer()
            
            // Custom toggle
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? onColor : offColor)
                    .frame(width: 48, height: 28)
                    .overlay(
                        Capsule()
                            .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0)
                    )
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .offset(x: configuration.isOn ? 10 : -10)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
    
    private var labelColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    private var onColor: Color {
        colorScheme == .dark ? terminalGreen : Color.blue
    }
    
    private var offColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? terminalGreen.opacity(0.3) : Color.clear
    }
}

// MARK: - Themed Button Styles
struct ThemedButtonStyle: ButtonStyle {
    let role: ButtonRole?
    @Environment(\.colorScheme) var colorScheme
    private let terminalGreen = Color(hex: "4cc9f0")
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(buttonFont)
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private var buttonFont: Font {
        if colorScheme == .dark {
            return .system(size: 16, weight: .semibold, design: .monospaced)
        } else {
            return .system(size: 16, weight: .semibold)
        }
    }
    
    private var textColor: Color {
        switch role {
        case .destructive:
            return Color.red
        case .cancel:
            return colorScheme == .dark ? terminalGreen.opacity(0.7) : Color.black.opacity(0.6)
        default:
            return colorScheme == .dark ? terminalGreen : Color.blue
        }
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        let opacity = isPressed ? 0.15 : 0.1
        
        switch role {
        case .destructive:
            return Color.red.opacity(opacity)
        case .cancel:
            return colorScheme == .dark ?
                Color.white.opacity(opacity * 0.5) :
                Color.black.opacity(opacity * 0.5)
        default:
            return colorScheme == .dark ?
                terminalGreen.opacity(opacity) :
                Color.blue.opacity(opacity)
        }
    }
    
    private var borderColor: Color {
        switch role {
        case .destructive:
            return Color.red.opacity(0.3)
        case .cancel:
            return colorScheme == .dark ?
                Color.white.opacity(0.1) :
                Color.clear
        default:
            return colorScheme == .dark ?
                terminalGreen.opacity(0.3) :
                Color.clear
        }
    }
}

// MARK: - Themed Info Row
struct ThemedInfoRow: View {
    let title: String
    let value: String
    let icon: String?
    
    @Environment(\.colorScheme) var colorScheme
    
    init(title: String, value: String, icon: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
            }
            
            Text(title)
                .font(titleFont)
                .foregroundColor(titleColor)
            
            Spacer()
            
            Text(value)
                .font(valueFont)
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 4)
    }
    
    private var titleFont: Font {
        colorScheme == .dark ?
            .system(size: 15, design: .monospaced) :
            .system(size: 15)
    }
    
    private var valueFont: Font {
        colorScheme == .dark ?
            .system(size: 15, weight: .medium, design: .monospaced) :
            .system(size: 15, weight: .medium)
    }
    
    private var iconColor: Color {
        colorScheme == .dark ?
            Color(hex: "4cc9f0").opacity(0.7) :
            Color.blue
    }
    
    private var titleColor: Color {
        colorScheme == .dark ?
            Color.white.opacity(0.8) :
            Color.black
    }
    
    private var valueColor: Color {
        colorScheme == .dark ?
            Color(hex: "4cc9f0") :
            Color.black.opacity(0.6)
    }
}

// MARK: - Themed Picker Style
struct ThemedPickerRow<SelectionValue: Hashable>: View {
    let title: String
    let selection: Binding<SelectionValue>
    let options: [(value: SelectionValue, label: String)]
    
    @Environment(\.colorScheme) var colorScheme
    private let terminalGreen = Color(hex: "4cc9f0")
    
    var body: some View {
        HStack {
            Text(title)
                .font(titleFont)
                .foregroundColor(titleColor)
            
            Spacer()
            
            Menu {
                ForEach(options, id: \.value) { option in
                    Button(action: {
                        selection.wrappedValue = option.value
                    }) {
                        HStack {
                            Text(option.label)
                            if selection.wrappedValue == option.value {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currentLabel)
                        .font(valueFont)
                        .foregroundColor(valueColor)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(valueColor.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0)
                        )
                )
            }
        }
    }
    
    private var currentLabel: String {
        options.first { $0.value == selection.wrappedValue }?.label ?? ""
    }
    
    private var titleFont: Font {
        colorScheme == .dark ?
            .system(size: 15, design: .monospaced) :
            .system(size: 15)
    }
    
    private var valueFont: Font {
        colorScheme == .dark ?
            .system(size: 14, weight: .medium, design: .monospaced) :
            .system(size: 14, weight: .medium)
    }
    
    private var titleColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.8) : Color.black
    }
    
    private var valueColor: Color {
        colorScheme == .dark ? terminalGreen : Color.blue
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ?
            Color.white.opacity(0.05) :
            Color.black.opacity(0.05)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ?
            terminalGreen.opacity(0.2) :
            Color.clear
    }
}

// MARK: - Themed Alert/Warning Banner
struct ThemedAlertBanner: View {
    let message: String
    let type: AlertType
    
    enum AlertType {
        case info, warning, success, error
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
            
            Text(message)
                .font(messageFont)
                .foregroundColor(textColor)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch type {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    private var messageFont: Font {
        colorScheme == .dark ?
            .system(size: 14, design: .monospaced) :
            .system(size: 14)
    }
    
    private var iconColor: Color {
        switch type {
        case .info: return colorScheme == .dark ? Color(hex: "4cc9f0") : Color.blue
        case .warning: return Color.orange
        case .success: return Color.green
        case .error: return Color.red
        }
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.8)
    }
    
    private var backgroundColor: Color {
        iconColor.opacity(colorScheme == .dark ? 0.15 : 0.1)
    }
    
    private var borderColor: Color {
        iconColor.opacity(0.3)
    }
}

// MARK: - Section Footer Style
struct ThemedSectionFooter: View {
    let text: String
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(text)
            .font(footerFont)
            .foregroundColor(footerColor)
            .padding(.top, 4)
    }
    
    private var footerFont: Font {
        if colorScheme == .dark {
            return .system(size: 12, design: .monospaced)
        } else {
            return .custom("American Typewriter", size: 12)
        }
    }
    
    private var footerColor: Color {
        colorScheme == .dark ?
            Color(hex: "4cc9f0").opacity(0.5) :
            Color.black.opacity(0.4)
    }
}



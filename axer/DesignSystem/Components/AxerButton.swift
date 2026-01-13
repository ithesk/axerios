import SwiftUI

struct AxerButton: View {
    let title: String
    let style: ButtonStyle
    let isLoading: Bool
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
        case outline
        case text
    }

    init(
        _ title: String,
        style: ButtonStyle = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AxerSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.8)
                }
                Text(title)
                    .font(AxerTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(AxerSpacing.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AxerSpacing.cornerRadius)
                    .stroke(borderColor, lineWidth: style == .outline ? 2 : 0)
            )
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return AxerColors.buttonPrimary
        case .secondary:
            return AxerColors.buttonSecondary
        case .outline, .text:
            return .clear
        }
    }

    private var textColor: Color {
        switch style {
        case .primary:
            return AxerColors.textInverse
        case .secondary, .outline, .text:
            return AxerColors.primary
        }
    }

    private var borderColor: Color {
        switch style {
        case .outline:
            return AxerColors.primary
        default:
            return .clear
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        AxerButton("Iniciar Sesion", style: .primary) {}
        AxerButton("Crear Cuenta", style: .secondary) {}
        AxerButton("Cancelar", style: .outline) {}
        AxerButton("Cargando...", style: .primary, isLoading: true) {}
    }
    .padding()
}

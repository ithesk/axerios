import SwiftUI

struct AxerTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: AxerSpacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(isFocused ? AxerColors.primary : AxerColors.textSecondary)
                    .frame(width: 20)
            }

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                }
            }
            .font(AxerTypography.body)
            .focused($isFocused)
        }
        .padding(.horizontal, AxerSpacing.md)
        .frame(height: 56)
        .background(AxerColors.surface)
        .cornerRadius(AxerSpacing.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AxerSpacing.cornerRadius)
                .stroke(isFocused ? AxerColors.primary : AxerColors.border, lineWidth: isFocused ? 2 : 1)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        AxerTextField(placeholder: "Email", text: .constant(""), icon: "envelope")
        AxerTextField(placeholder: "Password", text: .constant(""), isSecure: true, icon: "lock")
    }
    .padding()
    .background(AxerColors.background)
}

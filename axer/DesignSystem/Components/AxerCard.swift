import SwiftUI

struct AxerCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AxerSpacing.md)
            .background(AxerColors.surface)
            .cornerRadius(AxerSpacing.cornerRadius)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    AxerCard {
        VStack(alignment: .leading, spacing: 8) {
            Text("Titulo de la Card")
                .font(AxerTypography.headline)
            Text("Este es el contenido de la card con informacion relevante.")
                .font(AxerTypography.body)
                .foregroundColor(AxerColors.textSecondary)
        }
    }
    .padding()
    .background(AxerColors.background)
}

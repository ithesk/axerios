import SwiftUI

struct OfflineBanner: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor

    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: AxerSpacing.xs) {
                Image(systemName: "wifi.slash")
                Text("Sin conexion a internet")
                    .font(AxerTypography.footnote)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AxerSpacing.xs)
            .background(AxerColors.warning)
        }
    }
}

#Preview {
    VStack {
        OfflineBanner()
        Spacer()
    }
    .environmentObject(NetworkMonitor())
}

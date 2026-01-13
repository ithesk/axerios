import SwiftUI

struct OfflineBanner: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor

    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: AxerSpacing.xs) {
                Image(systemName: "wifi.slash")
                Text(L10n.Offline.noConnection)
                    .font(AxerTypography.footnote)
            }
            .foregroundColor(AxerColors.textInverse)
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

import SwiftUI
import PhotosUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var router: Router

    @StateObject private var ordersViewModel = OrdersViewModel()
    @State private var showNewOrder = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false

    var body: some View {
        ZStack {
            AxerColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                OfflineBanner()

                ScrollView {
                    VStack(spacing: 20) {
                        welcomeHeader
                        quickStatsSection
                        recentOrdersSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                }
            }

            // Floating button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingButton
                }
            }
            .padding(20)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showNewOrder) {
            NewOrderView(viewModel: ordersViewModel)
        }
        .task {
            if let workshopId = sessionStore.workshop?.id {
                await ordersViewModel.loadOrders(workshopId: workshopId)
            }
        }
        .onChange(of: sessionStore.workshop?.id) { _, newWorkshopId in
            // Reload orders when workshop becomes available (after session restore)
            if let workshopId = newWorkshopId {
                Task {
                    await ordersViewModel.loadOrders(workshopId: workshopId)
                }
            }
        }
    }

    private var floatingButton: some View {
        Button {
            showNewOrder = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                Text("Nueva Orden")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(hex: "0D47A1"))
            .cornerRadius(28)
            .shadow(color: Color(hex: "0D47A1").opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private var welcomeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Hola \(sessionStore.profile?.firstName ?? "Usuario")")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "0F172A"))
                    Text("👋")
                        .font(.system(size: 26))
                }

                if let workshop = sessionStore.workshop {
                    Text(workshop.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "0D47A1"))
                }
            }
            Spacer()

            // Avatar con PhotosPicker
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    if let avatarUrl = sessionStore.profile?.avatarUrl,
                       let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure(_):
                                avatarPlaceholder
                            case .empty:
                                ProgressView()
                            @unknown default:
                                avatarPlaceholder
                            }
                        }
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                    } else {
                        avatarPlaceholder
                    }

                    // Overlay de carga
                    if isUploadingAvatar {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 52, height: 52)
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await handlePhotoSelection(newItem)
                }
            }
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(hex: "E3F2FD"))
            .frame(width: 52, height: 52)
            .overlay(
                Text(initials)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "0D47A1"))
            )
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item = item else {
            print("📷 [Avatar] No item selected")
            return
        }

        print("📷 [Avatar] Photo selected, starting upload...")
        isUploadingAvatar = true
        defer {
            isUploadingAvatar = false
            print("📷 [Avatar] Upload process finished")
        }

        do {
            print("📷 [Avatar] Loading transferable data...")
            guard let data = try await item.loadTransferable(type: Data.self) else {
                print("📷 [Avatar] ERROR: Could not load data from photo")
                return
            }
            print("📷 [Avatar] Data loaded: \(data.count) bytes")

            // Comprimir imagen
            guard let uiImage = UIImage(data: data) else {
                print("📷 [Avatar] ERROR: Could not create UIImage from data")
                return
            }
            print("📷 [Avatar] UIImage created: \(uiImage.size)")

            guard let compressedData = uiImage.jpegData(compressionQuality: 0.7) else {
                print("📷 [Avatar] ERROR: Could not compress image")
                return
            }
            print("📷 [Avatar] Compressed to: \(compressedData.count) bytes")

            print("📷 [Avatar] Calling sessionStore.uploadAvatar...")
            let url = try await sessionStore.uploadAvatar(imageData: compressedData)
            print("📷 [Avatar] SUCCESS! Avatar URL: \(url)")
        } catch {
            print("📷 [Avatar] ERROR uploading: \(error.localizedDescription)")
            print("📷 [Avatar] Full error: \(error)")
        }
    }

    private var quickStatsSection: some View {
        let stats = ordersViewModel.orderStats()
        let activeOrders = ordersViewModel.activeOrders.count
        let diagnosingCount = ordersViewModel.orders.filter { $0.status == .diagnosing }.count
        let inRepairCount = ordersViewModel.orders.filter { $0.status == .inRepair }.count
        let readyCount = ordersViewModel.orders.filter { $0.status == .ready }.count
        let totalActive = max(activeOrders, 1)
        let progress = Double(inRepairCount + readyCount) / Double(totalActive)

        return VStack(spacing: 16) {
            // Main Orders Card
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(activeOrders) Órdenes Activas")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "0F172A"))

                    Text("\(readyCount) listas para entrega")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "64748B"))

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "E2E8F0"))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "0D47A1"))
                                .frame(width: geometry.size.width * progress, height: 8)
                        }
                    }
                    .frame(height: 8)
                    .padding(.top, 4)

                    // Status chips
                    HStack(spacing: 12) {
                        StatusChip(icon: "wrench.fill", label: "Reparando", count: inRepairCount, color: Color(hex: "F59E0B"))
                        StatusChip(icon: "magnifyingglass", label: "Diagnóstico", count: diagnosingCount, color: Color(hex: "0D47A1"))
                    }
                    .padding(.top, 8)
                }

                Spacer()

                // Circular indicator
                ZStack {
                    Circle()
                        .stroke(Color(hex: "E2E8F0"), lineWidth: 4)
                        .frame(width: 52, height: 52)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color(hex: "0D47A1"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))

                    Text("\(readyCount)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "0D47A1"))
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    private var recentOrdersSection: some View {
        VStack(alignment: .leading, spacing: AxerSpacing.sm) {
            HStack {
                Text("Ordenes Recientes")
                    .font(AxerTypography.headline)
                    .foregroundColor(AxerColors.textPrimary)

                Spacer()

                if !ordersViewModel.orders.isEmpty {
                    Button {
                        router.navigate(to: .orders)
                    } label: {
                        Text("Ver todas")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AxerColors.primary)
                    }
                }
            }

            if ordersViewModel.orders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "CBD5E1"))

                    Text("Sin ordenes aun")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "64748B"))

                    Text("Crea tu primera orden")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "94A3B8"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.white)
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    ForEach(ordersViewModel.activeOrders.prefix(3)) { order in
                        Button {
                            router.navigate(to: .orderDetail(order.id))
                        } label: {
                            OrderCard(order: order)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var initials: String {
        guard let name = sessionStore.profile?.fullName else { return "U" }
        let components = name.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }.map { String($0) }
        return initials.joined().uppercased()
    }
}

// MARK: - Status Chip

struct StatusChip: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "64748B"))

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(SessionStore())
            .environmentObject(NetworkMonitor())
            .environmentObject(Router())
    }
}

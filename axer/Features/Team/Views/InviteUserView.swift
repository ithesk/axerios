import SwiftUI

struct InviteUserView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionStore: SessionStore
    @ObservedObject var viewModel: TeamViewModel

    @State private var selectedRole: UserRole = .technician
    @State private var createdInvite: Invite?
    @State private var isCreating = false
    @State private var showCopiedAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let invite = createdInvite {
                    inviteCreatedView(invite: invite)
                } else {
                    createInviteView
                }
            }
            .background(Color(hex: "F8FAFC"))
            .navigationTitle(createdInvite == nil ? "Invitar Usuario" : "Invitacion Creada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "64748B"))
                }
            }
        }
    }

    // MARK: - Create Invite View
    private var createInviteView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "E3F2FD"))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "0D47A1"))
            }

            // Text
            VStack(spacing: 8) {
                Text("Agregar al Equipo")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))

                Text("Genera un codigo de invitacion para que un nuevo miembro se una a tu taller.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "64748B"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Role selector
            VStack(alignment: .leading, spacing: 12) {
                Text("Rol del nuevo miembro")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "64748B"))

                HStack(spacing: 12) {
                    RoleButton(
                        title: "Tecnico",
                        description: "Puede ver y actualizar ordenes",
                        icon: "wrench.and.screwdriver",
                        isSelected: selectedRole == .technician
                    ) {
                        selectedRole = .technician
                    }

                    RoleButton(
                        title: "Admin",
                        description: "Control total del taller",
                        icon: "person.badge.key",
                        isSelected: selectedRole == .admin
                    ) {
                        selectedRole = .admin
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Create button
            Button {
                Task { await createInvite() }
            } label: {
                HStack {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00BCD4")))
                    }
                    Text("Generar Invitacion")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(Color(hex: "00BCD4"))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(hex: "0D2137"))
                .cornerRadius(28)
            }
            .disabled(isCreating)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Invite Created View
    private func inviteCreatedView(invite: Invite) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(Color(hex: "D1FAE5"))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "22C55E"))
            }

            // Text
            VStack(spacing: 8) {
                Text("Invitacion Lista!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "0D2137"))

                Text("Comparte este codigo con el nuevo miembro del equipo.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "64748B"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Code display
            VStack(spacing: 16) {
                Text(invite.inviteCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "0D47A1"))
                    .tracking(4)

                Button {
                    UIPasteboard.general.string = invite.token
                    showCopiedAlert = true

                    // Hide after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopiedAlert = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                        Text(showCopiedAlert ? "Copiado!" : "Copiar codigo completo")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "0D47A1"))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "E3F2FD"))
            .cornerRadius(16)
            .padding(.horizontal, 24)

            // Info
            VStack(spacing: 8) {
                Label("Rol: \(invite.role.displayName)", systemImage: "person.fill")
                Label("Expira en 7 dias", systemImage: "clock")
            }
            .font(.system(size: 14))
            .foregroundColor(Color(hex: "64748B"))

            Spacer()

            // Share button
            Button {
                shareInvite(invite)
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Compartir")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(hex: "00BCD4"))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(hex: "0D2137"))
                .cornerRadius(28)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Actions
    private func createInvite() async {
        guard let workshopId = sessionStore.workshop?.id else { return }

        isCreating = true
        if let invite = await viewModel.createInvite(workshopId: workshopId, role: selectedRole) {
            withAnimation {
                createdInvite = invite
            }
        }
        isCreating = false
    }

    private func shareInvite(_ invite: Invite) {
        let message = """
        Te invito a unirte a \(sessionStore.workshop?.name ?? "nuestro taller") en axer!

        Codigo de invitacion: \(invite.inviteCode)

        Descarga la app y usa este codigo para unirte al equipo.
        """

        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Role Button
struct RoleButton: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? Color(hex: "0D47A1") : Color(hex: "94A3B8"))

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: "0D2137") : Color(hex: "64748B"))

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "94A3B8"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(isSelected ? Color(hex: "E3F2FD") : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "0D47A1") : Color(hex: "E2E8F0"), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

#Preview {
    InviteUserView(viewModel: TeamViewModel())
        .environmentObject(SessionStore())
}

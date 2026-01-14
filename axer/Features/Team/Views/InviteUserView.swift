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
            .background(AxerColors.background)
            .navigationTitle(createdInvite == nil ? L10n.Invite.title : L10n.Invite.createdTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.close) {
                        dismiss()
                    }
                    .foregroundColor(AxerColors.textSecondary)
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
                    .fill(AxerColors.primaryLight)
                    .frame(width: 100, height: 100)

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 40))
                    .foregroundColor(AxerColors.primary)
            }

            // Text
            VStack(spacing: 8) {
                Text(L10n.Invite.addToTeam)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AxerColors.textPrimary)

                Text(L10n.Invite.subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(AxerColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Role selector
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.Invite.roleLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AxerColors.textSecondary)

                HStack(spacing: 12) {
                    RoleButton(
                        title: L10n.Invite.technician,
                        description: L10n.Invite.technicianDesc,
                        icon: "wrench.and.screwdriver",
                        isSelected: selectedRole == .technician
                    ) {
                        selectedRole = .technician
                    }

                    RoleButton(
                        title: L10n.Invite.admin,
                        description: L10n.Invite.adminDesc,
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
                            .progressViewStyle(CircularProgressViewStyle(tint: AxerColors.accent))
                    }
                    Text(L10n.Invite.generate)
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(AxerColors.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(AxerColors.textPrimary)
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
                    .fill(AxerColors.successLight)
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(AxerColors.success)
            }

            // Text
            VStack(spacing: 8) {
                Text(L10n.Invite.readyTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AxerColors.textPrimary)

                Text(L10n.Invite.shareHint)
                    .font(.system(size: 16))
                    .foregroundColor(AxerColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Code display
            VStack(spacing: 16) {
                Text(invite.inviteCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(AxerColors.primary)
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
                        Text(showCopiedAlert ? L10n.Invite.copied : L10n.Invite.copyCode)
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AxerColors.primary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(AxerColors.primaryLight)
            .cornerRadius(16)
            .padding(.horizontal, 24)

            // Info
            VStack(spacing: 8) {
                Label(L10n.Invite.roleFormat(invite.role.displayName), systemImage: "person.fill")
                Label(L10n.Invite.expires7Days, systemImage: "clock")
            }
            .font(.system(size: 14))
            .foregroundColor(AxerColors.textSecondary)

            Spacer()

            // Share button
            Button {
                shareInvite(invite)
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(L10n.Invite.share)
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AxerColors.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(AxerColors.textPrimary)
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
            // Configure popover for iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(
                    x: rootVC.view.bounds.midX,
                    y: rootVC.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
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
                    .foregroundColor(isSelected ? AxerColors.primary : AxerColors.textTertiary)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? AxerColors.textPrimary : AxerColors.textSecondary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(AxerColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(isSelected ? AxerColors.primaryLight : AxerColors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AxerColors.primary : AxerColors.border, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

#Preview {
    InviteUserView(viewModel: TeamViewModel())
        .environmentObject(SessionStore())
}

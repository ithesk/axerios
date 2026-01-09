import SwiftUI

struct TeamView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var viewModel = TeamViewModel()
    @State private var showInviteSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Team members
                membersSection

                // Pending invites
                if !viewModel.invites.isEmpty {
                    invitesSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color(hex: "F8FAFC"))
        .navigationTitle("Equipo")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if sessionStore.profile?.role == .admin {
                    Button {
                        showInviteSheet = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "0D47A1"))
                    }
                }
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteUserView(viewModel: viewModel)
        }
        .task {
            if let workshopId = sessionStore.workshop?.id {
                await viewModel.loadTeam(workshopId: workshopId)
            }
        }
        .refreshable {
            if let workshopId = sessionStore.workshop?.id {
                await viewModel.loadTeam(workshopId: workshopId)
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sessionStore.workshop?.name ?? "Tu Taller")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "0D2137"))

            Text("\(viewModel.members.count) miembro\(viewModel.members.count == 1 ? "" : "s")")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "64748B"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Members Section
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Miembros")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "64748B"))
                .textCase(.uppercase)

            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    ForEach(viewModel.members) { member in
                        MemberRow(member: member, isCurrentUser: member.id == sessionStore.user?.id)

                        if member.id != viewModel.members.last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(12)
        }
    }

    // MARK: - Invites Section
    private var invitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invitaciones Pendientes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "64748B"))
                .textCase(.uppercase)

            VStack(spacing: 0) {
                ForEach(viewModel.invites) { invite in
                    InviteRow(invite: invite) {
                        Task {
                            await viewModel.deleteInvite(invite)
                        }
                    }

                    if invite.id != viewModel.invites.last?.id {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(12)
        }
    }
}

// MARK: - Member Row
struct MemberRow: View {
    let member: TeamMember
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color(hex: "E3F2FD"))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(initials)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "0D47A1"))
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.fullName ?? "Sin nombre")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "0D2137"))

                    if isCurrentUser {
                        Text("(Tú)")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "64748B"))
                    }
                }

                Text(member.role.displayName)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "64748B"))
            }

            Spacer()

            // Role badge
            Text(member.role == .admin ? "Admin" : "Técnico")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(member.role == .admin ? Color(hex: "0D47A1") : Color(hex: "64748B"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(member.role == .admin ? Color(hex: "E3F2FD") : Color(hex: "F1F5F9"))
                .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var initials: String {
        guard let name = member.fullName else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Invite Row
struct InviteRow: View {
    let invite: Invite
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Circle()
                .fill(Color(hex: "FEF3C7"))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "envelope")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "D97706"))
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text("Código: \(invite.inviteCode)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "0D2137"))

                Text("Expira \(expiresText)")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "64748B"))
            }

            Spacer()

            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(hex: "CBD5E1"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var expiresText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: invite.expiresAt, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        TeamView()
            .environmentObject(SessionStore())
    }
}

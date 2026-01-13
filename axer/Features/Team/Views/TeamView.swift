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
        .background(AxerColors.background)
        .navigationTitle(L10n.Team.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if sessionStore.profile?.role == .admin {
                    Button {
                        showInviteSheet = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AxerColors.primary)
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
                .foregroundColor(AxerColors.textPrimary)

            Text(L10n.Team.membersCount(viewModel.members.count))
                .font(.system(size: 15))
                .foregroundColor(AxerColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Members Section
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Team.members)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AxerColors.textSecondary)
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
            .background(AxerColors.surface)
            .cornerRadius(12)
        }
    }

    // MARK: - Invites Section
    private var invitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Team.pendingInvites)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AxerColors.textSecondary)
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
            .background(AxerColors.surface)
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
                .fill(AxerColors.primaryLight)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(initials)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AxerColors.primary)
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.fullName ?? "Sin nombre")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AxerColors.textPrimary)

                    if isCurrentUser {
                        Text(L10n.Team.you)
                            .font(.system(size: 14))
                            .foregroundColor(AxerColors.textSecondary)
                    }
                }

                Text(member.role.displayName)
                    .font(.system(size: 14))
                    .foregroundColor(AxerColors.textSecondary)
            }

            Spacer()

            // Role badge
            Text(member.role == .admin ? L10n.Role.admin : L10n.Role.technician)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(member.role == .admin ? AxerColors.primary : AxerColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(member.role == .admin ? AxerColors.primaryLight : AxerColors.surfaceSecondary)
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
                .fill(AxerColors.warningLight)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "envelope")
                        .font(.system(size: 18))
                        .foregroundColor(AxerColors.warning)
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Team.inviteCode(invite.inviteCode))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AxerColors.textPrimary)

                Text(L10n.Team.expires(expiresText))
                    .font(.system(size: 14))
                    .foregroundColor(AxerColors.textSecondary)
            }

            Spacer()

            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AxerColors.textTertiary)
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

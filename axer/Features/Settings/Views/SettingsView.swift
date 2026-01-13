import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showEditWorkshop = false
    @State private var isDeleting = false

    var body: some View {
        List {
            // Profile Section
            Section {
                HStack(spacing: 16) {
                    Circle()
                        .fill(AxerColors.primaryLight)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(initials)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AxerColors.primary)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(sessionStore.profile?.fullName ?? L10n.Settings.user)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AxerColors.textPrimary)

                        Text(sessionStore.profile?.role.displayName ?? "")
                            .font(.system(size: 14))
                            .foregroundColor(AxerColors.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // Workshop Section
            if let workshop = sessionStore.workshop {
                Section(L10n.Settings.workshopSection) {
                    if sessionStore.profile?.role == .admin {
                        Button {
                            showEditWorkshop = true
                        } label: {
                            HStack {
                                Label(L10n.Settings.name, systemImage: "building.2.fill")
                                Spacer()
                                Text(workshop.name)
                                    .foregroundColor(AxerColors.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AxerColors.textTertiary)
                            }
                        }
                        .foregroundColor(.primary)
                    } else {
                        HStack {
                            Label(L10n.Settings.name, systemImage: "building.2.fill")
                            Spacer()
                            Text(workshop.name)
                                .foregroundColor(AxerColors.textSecondary)
                        }
                    }

                    if let phone = workshop.phone {
                        HStack {
                            Label(L10n.Settings.phone, systemImage: "phone.fill")
                            Spacer()
                            Text(phone)
                                .foregroundColor(AxerColors.textSecondary)
                        }
                    }

                    HStack {
                        Label(L10n.Settings.orderPrefix, systemImage: "number.circle.fill")
                        Spacer()
                        Text(workshop.orderPrefix)
                            .foregroundColor(AxerColors.textSecondary)
                    }
                }

                Section {
                    if sessionStore.profile?.role == .admin {
                        Button {
                            showEditWorkshop = true
                        } label: {
                            HStack {
                                Label(L10n.Settings.tax, systemImage: "number.circle.fill")
                                Spacer()
                                Text("\(workshop.displayTaxName) (\(workshop.displayTaxRate)%)")
                                    .foregroundColor(AxerColors.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AxerColors.textTertiary)
                            }
                        }
                        .foregroundColor(.primary)

                        Button {
                            showEditWorkshop = true
                        } label: {
                            HStack {
                                Label(L10n.Settings.currency, systemImage: "dollarsign.circle.fill")
                                Spacer()
                                Text("\(workshop.displayCurrencySymbol) (\(workshop.displayCurrencyCode))")
                                    .foregroundColor(AxerColors.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AxerColors.textTertiary)
                            }
                        }
                        .foregroundColor(.primary)
                    } else {
                        HStack {
                            Label(L10n.Settings.tax, systemImage: "number.circle.fill")
                            Spacer()
                            Text("\(workshop.displayTaxName) (\(workshop.displayTaxRate)%)")
                                .foregroundColor(AxerColors.textSecondary)
                        }

                        HStack {
                            Label(L10n.Settings.currency, systemImage: "dollarsign.circle.fill")
                            Spacer()
                            Text("\(workshop.displayCurrencySymbol) (\(workshop.displayCurrencyCode))")
                                .foregroundColor(AxerColors.textSecondary)
                        }
                    }
                } header: {
                    Text(L10n.Settings.fiscalConfig)
                } footer: {
                    if sessionStore.profile?.role == .admin {
                        Text(L10n.Settings.tapToEdit)
                            .font(.system(size: 12))
                    }
                }
            }

            // Services Section
            Section(L10n.Settings.servicesSection) {
                NavigationLink {
                    ServiceManagementView()
                } label: {
                    Label(L10n.Settings.serviceCatalog, systemImage: "wrench.and.screwdriver.fill")
                }
            }

            // Team Section (solo admin)
            if sessionStore.profile?.role == .admin {
                Section(L10n.Settings.teamSection) {
                     NavigationLink {
                        TeamView()
                    } label: {
                        Label(L10n.Settings.manageTeam, systemImage: "person.2.fill")
                    }
                }
            }

            // App Info Section
            Section(L10n.Settings.appSection) {
                HStack {
                    Label(L10n.Settings.version, systemImage: "info.circle.fill")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(AxerColors.textSecondary)
                }
            }

            // Legal Section
            Section(L10n.Settings.legalSection) {
                Link(destination: URL(string: "https://axer.app/privacy")!) {
                    HStack {
                        Label(L10n.Settings.privacyPolicy, systemImage: "hand.raised.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AxerColors.textTertiary)
                    }
                    .foregroundColor(.primary)
                }

                Link(destination: URL(string: "https://axer.app/terms")!) {
                    HStack {
                        Label(L10n.Settings.termsOfService, systemImage: "doc.text.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AxerColors.textTertiary)
                    }
                    .foregroundColor(.primary)
                }

                Link(destination: URL(string: "mailto:soporte@axer.app")!) {
                    HStack {
                        Label(L10n.Settings.contactSupport, systemImage: "envelope.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AxerColors.textTertiary)
                    }
                    .foregroundColor(.primary)
                }
            }

            // Logout Section
            Section {
                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Label(L10n.Settings.logout, systemImage: "rectangle.portrait.and.arrow.right.fill")
                        Spacer()
                    }
                }
            }

            // Delete Account Section
            Section {
                Button(role: .destructive) {
                    showDeleteAccountAlert = true
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                                .tint(.red)
                        } else {
                            Label(L10n.Settings.deleteAccount, systemImage: "trash.fill")
                        }
                        Spacer()
                    }
                }
                .disabled(isDeleting)
            } footer: {
                Text(L10n.Settings.deleteAccountFooter)
                    .font(.system(size: 12))
            }
        }
        .navigationTitle(L10n.Settings.title)
        .navigationBarTitleDisplayMode(.large)
        .alert(L10n.Settings.logoutConfirmTitle, isPresented: $showLogoutAlert) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Settings.logoutButton, role: .destructive) {
                Task {
                    try? await sessionStore.signOut()
                }
            }
        } message: {
            Text(L10n.Settings.logoutConfirmMessage)
        }
        .alert(L10n.Settings.deleteAccountTitle, isPresented: $showDeleteAccountAlert) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Settings.deleteAccountButton, role: .destructive) {
                Task {
                    isDeleting = true
                    do {
                        try await sessionStore.deleteAccount()
                    } catch {
                        HapticManager.error()
                    }
                    isDeleting = false
                }
            }
        } message: {
            Text(L10n.Settings.deleteAccountMessage)
        }
        .sheet(isPresented: $showEditWorkshop) {
            WorkshopEditView()
        }
    }

    private var initials: String {
        guard let name = sessionStore.profile?.fullName else { return "U" }
        let components = name.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }.map { String($0) }
        return initials.joined().uppercased()
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SessionStore())
    }
}

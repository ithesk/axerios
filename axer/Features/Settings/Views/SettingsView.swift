import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var showLogoutAlert = false
    @State private var showEditWorkshop = false

    var body: some View {
        List {
            // Profile Section
            Section {
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color(hex: "E3F2FD"))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(initials)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(hex: "0D47A1"))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(sessionStore.profile?.fullName ?? "Usuario")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(hex: "0D2137"))

                        Text(sessionStore.profile?.role.displayName ?? "")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "64748B"))
                    }
                }
                .padding(.vertical, 8)
            }

            // Workshop Section
            if let workshop = sessionStore.workshop {
                Section("Taller") {
                    if sessionStore.profile?.role == .admin {
                        Button {
                            showEditWorkshop = true
                        } label: {
                            HStack {
                                Label("Nombre", systemImage: "building.2.fill")
                                Spacer()
                                Text(workshop.name)
                                    .foregroundColor(Color(hex: "64748B"))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "C7C7CC"))
                            }
                        }
                        .foregroundColor(.primary)
                    } else {
                        HStack {
                            Label("Nombre", systemImage: "building.2.fill")
                            Spacer()
                            Text(workshop.name)
                                .foregroundColor(Color(hex: "64748B"))
                        }
                    }

                    if let phone = workshop.phone {
                        HStack {
                            Label("Telefono", systemImage: "phone.fill")
                            Spacer()
                            Text(phone)
                                .foregroundColor(Color(hex: "64748B"))
                        }
                    }

                    HStack {
                        Label("Prefijo ordenes", systemImage: "number.circle.fill")
                        Spacer()
                        Text(workshop.orderPrefix)
                            .foregroundColor(Color(hex: "64748B"))
                    }
                }

                Section {
                    if sessionStore.profile?.role == .admin {
                        Button {
                            showEditWorkshop = true
                        } label: {
                            HStack {
                                Label("Impuesto", systemImage: "percent.circle.fill")
                                Spacer()
                                Text("\(workshop.displayTaxName) (\(workshop.displayTaxRate)%)")
                                    .foregroundColor(Color(hex: "64748B"))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "C7C7CC"))
                            }
                        }
                        .foregroundColor(.primary)

                        Button {
                            showEditWorkshop = true
                        } label: {
                            HStack {
                                Label("Moneda", systemImage: "dollarsign.circle.fill")
                                Spacer()
                                Text("\(workshop.displayCurrencySymbol) (\(workshop.displayCurrencyCode))")
                                    .foregroundColor(Color(hex: "64748B"))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "C7C7CC"))
                            }
                        }
                        .foregroundColor(.primary)
                    } else {
                        HStack {
                            Label("Impuesto", systemImage: "percent.circle.fill")
                            Spacer()
                            Text("\(workshop.displayTaxName) (\(workshop.displayTaxRate)%)")
                                .foregroundColor(Color(hex: "64748B"))
                        }

                        HStack {
                            Label("Moneda", systemImage: "dollarsign.circle.fill")
                            Spacer()
                            Text("\(workshop.displayCurrencySymbol) (\(workshop.displayCurrencyCode))")
                                .foregroundColor(Color(hex: "64748B"))
                        }
                    }
                } header: {
                    Text("Configuracion Fiscal")
                } footer: {
                    if sessionStore.profile?.role == .admin {
                        Text("Toca para editar la configuracion")
                            .font(.system(size: 12))
                    }
                }
            }

            // Services Section
            Section("Servicios") {
                NavigationLink {
                    ServiceManagementView()
                } label: {
                    Label("Catalogo de servicios", systemImage: "wrench.and.screwdriver.fill")
                }
            }

            // Team Section (solo admin)
            if sessionStore.profile?.role == .admin {
                Section("Equipo") {
                     NavigationLink {
                        TeamView()
                    } label: {
                        Label("Administrar equipo", systemImage: "person.2.fill")
                    }
                }
            }

            // App Info Section
            Section("Aplicación") {
                HStack {
                    Label("Versión", systemImage: "info.circle.fill")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(Color(hex: "64748B"))
                }
            }

            // Logout Section
            Section {
                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right.fill")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.large)
        .alert("Cerrar Sesión", isPresented: $showLogoutAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Salir", role: .destructive) {
                Task {
                    try? await sessionStore.signOut()
                }
            }
        } message: {
            Text("Estas seguro que quieres cerrar sesion?")
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

import Foundation
import Supabase

enum SessionState: Equatable {
    case loading
    case unauthenticated
    case authenticated
    case pendingEmailVerification
}

// Datos temporales del workshop mientras se verifica el email
struct PendingWorkshopData: Codable {
    let workshopName: String
    let workshopPhone: String?
    let fullName: String
    let email: String
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var state: SessionState = .loading
    @Published private(set) var user: User?
    @Published private(set) var profile: Profile?
    @Published private(set) var workshop: Workshop?
    @Published var pendingEmail: String?
    @Published var shouldShowOnboarding = false

    private let supabase = SupabaseClient.shared
    private let pendingDataKey = "pendingWorkshopData"

    func initialize() async {
        print("🚀 [Session] initialize() llamado")
        do {
            let session = try await supabase.client.auth.session
            self.user = session.user
            print("✅ [Session] Sesión existente encontrada: \(session.user.id)")
            await loadUserData()

            // Check if we have pending workshop data to complete
            if let pendingData = getPendingWorkshopData() {
                print("📝 [Session] Hay datos pendientes de workshop, completando...")
                await completePendingWorkshopCreation(data: pendingData)
            }

            state = .authenticated
            print("✅ [Session] Estado: authenticated")
        } catch {
            print("🟡 [Session] No hay sesión activa: \(error.localizedDescription)")
            // Check if there's pending email verification
            if let pendingData = getPendingWorkshopData() {
                pendingEmail = pendingData.email
                state = .pendingEmailVerification
                print("📧 [Session] Estado: pendingEmailVerification para \(pendingData.email)")
            } else {
                state = .unauthenticated
                print("🔴 [Session] Estado: unauthenticated")
            }
        }

        // Listen for auth state changes
        Task {
            for await state in supabase.client.auth.authStateChanges {
                await handleAuthStateChange(state)
            }
        }
    }

    private func handleAuthStateChange(_ state: (event: AuthChangeEvent, session: Session?)) async {
        print("🔔 [Session] Auth state change: \(state.event)")
        switch state.event {
        case .signedIn:
            if let session = state.session {
                self.user = session.user
                print("✅ [Session] Usuario signed in: \(session.user.id)")
                print("📧 [Session] Email: \(session.user.email ?? "sin email")")

                // Check if we have pending workshop to create
                if let pendingData = getPendingWorkshopData() {
                    print("📝 [Session] Datos pendientes encontrados:")
                    print("   - Workshop: \(pendingData.workshopName)")
                    print("   - Usuario: \(pendingData.fullName)")
                    print("   - Email: \(pendingData.email)")
                    await completePendingWorkshopCreation(data: pendingData)
                } else {
                    print("ℹ️ [Session] No hay datos pendientes de workshop")
                }

                await loadUserData()
                self.state = .authenticated
                print("✅ [Session] Estado final: authenticated")
            }
        case .signedOut:
            print("🚪 [Session] Usuario signed out")
            self.user = nil
            self.profile = nil
            self.workshop = nil
            self.state = .unauthenticated
        default:
            print("ℹ️ [Session] Otro evento auth: \(state.event)")
            break
        }
    }

    func loadUserData() async {
        guard let userId = user?.id else {
            print("🔴 [Session] loadUserData: No hay user.id")
            return
        }

        print("🔵 [Session] loadUserData para userId: \(userId)")

        do {
            // Load profile
            let profileResponse: Profile = try await supabase.client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value

            self.profile = profileResponse
            print("🟢 [Session] Profile cargado: \(profileResponse.fullName ?? "sin nombre")")
            print("🔵 [Session] Profile.workshopId: \(String(describing: profileResponse.workshopId))")

            // Load workshop if profile has workshop_id
            if let workshopId = profileResponse.workshopId {
                print("🔵 [Session] Cargando workshop: \(workshopId)")
                let workshopResponse: Workshop = try await supabase.client
                    .from("workshops")
                    .select()
                    .eq("id", value: workshopId.uuidString)
                    .single()
                    .execute()
                    .value

                self.workshop = workshopResponse
                print("🟢 [Session] Workshop cargado: \(workshopResponse.name)")
            } else {
                print("🟡 [Session] Profile NO tiene workshop_id asignado!")
            }
        } catch {
            print("🔴 [Session] Error loading user data: \(error)")
        }
    }

    func signIn(email: String, password: String) async throws {
        try await supabase.client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        try await supabase.client.auth.signUp(email: email, password: password)
    }

    func signOut() async throws {
        try await supabase.client.auth.signOut()
    }

    // MARK: - Workshop Management

    func createWorkshopAndAdmin(
        workshopName: String,
        workshopPhone: String?,
        fullName: String,
        email: String,
        password: String
    ) async throws {
        print("📝 Iniciando creación de taller y admin...")

        // 1. Create user account
        print("📝 Paso 1: Creando usuario...")
        let authResponse: AuthResponse
        do {
            authResponse = try await supabase.client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )
            print("✅ Usuario creado: \(authResponse.user.id)")
        } catch {
            print("❌ Error creando usuario: \(error)")
            throw error
        }

        let userId = authResponse.user.id

        // 2. Create workshop
        print("📝 Paso 2: Creando taller...")
        struct WorkshopInsert: Encodable {
            let name: String
            let phone: String?
            let currency: String
            let order_prefix: String
        }

        let workshopData = WorkshopInsert(
            name: workshopName,
            phone: workshopPhone,
            currency: "DOP",
            order_prefix: "ORD"
        )

        let newWorkshop: Workshop
        do {
            let workshopResponse: [Workshop] = try await supabase.client
                .from("workshops")
                .insert(workshopData)
                .select()
                .execute()
                .value

            print("✅ Respuesta workshops: \(workshopResponse)")

            guard let workshop = workshopResponse.first else {
                print("❌ No se recibió workshop en respuesta")
                throw NSError(domain: "SessionStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear el taller - respuesta vacía"])
            }
            newWorkshop = workshop
            print("✅ Taller creado: \(newWorkshop.id)")
        } catch {
            print("❌ Error creando taller: \(error)")
            throw error
        }

        // 3. Update profile with workshop_id
        print("📝 Paso 3: Actualizando perfil...")
        struct ProfileUpdate: Encodable {
            let workshop_id: UUID
            let full_name: String
            let role: String
        }

        let profileData = ProfileUpdate(
            workshop_id: newWorkshop.id,
            full_name: fullName,
            role: "admin"
        )

        do {
            try await supabase.client
                .from("profiles")
                .update(profileData)
                .eq("id", value: userId.uuidString)
                .execute()
            print("✅ Perfil actualizado")
        } catch {
            print("❌ Error actualizando perfil: \(error)")
            throw error
        }

        // 4. Update local state
        print("📝 Paso 4: Actualizando estado local...")
        self.workshop = newWorkshop
        await loadUserData()
        print("✅ Proceso completado!")
    }

    func updateWorkshopConfig(currency: String, orderPrefix: String) async throws {
        guard let workshopId = workshop?.id else { return }

        struct WorkshopUpdate: Encodable {
            let currency: String
            let order_prefix: String
        }

        let updateData = WorkshopUpdate(currency: currency, order_prefix: orderPrefix)

        try await supabase.client
            .from("workshops")
            .update(updateData)
            .eq("id", value: workshopId.uuidString)
            .execute()

        // Reload workshop data
        await loadUserData()
    }

    // MARK: - Avatar Upload

    func uploadAvatar(imageData: Data) async throws -> String {
        guard let userId = user?.id else {
            throw NSError(domain: "SessionStore", code: 401, userInfo: [NSLocalizedDescriptionKey: "No hay usuario autenticado"])
        }

        let fileName = "\(userId.uuidString)/avatar.jpg"
        let bucketName = "avatars"

        // Upload to Supabase Storage
        try await supabase.client.storage
            .from(bucketName)
            .upload(
                path: fileName,
                file: imageData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        // Get public URL
        let publicURL = try supabase.client.storage
            .from(bucketName)
            .getPublicURL(path: fileName)

        // Update profile with avatar URL
        struct ProfileUpdate: Encodable {
            let avatar_url: String
        }

        try await supabase.client
            .from("profiles")
            .update(ProfileUpdate(avatar_url: publicURL.absoluteString))
            .eq("id", value: userId.uuidString)
            .execute()

        // Reload profile
        await loadUserData()

        return publicURL.absoluteString
    }

    // MARK: - Pending Workshop Data Management

    /// Guarda los datos del workshop temporalmente mientras se verifica el email
    func savePendingWorkshopData(
        workshopName: String,
        workshopPhone: String?,
        fullName: String,
        email: String
    ) {
        let data = PendingWorkshopData(
            workshopName: workshopName,
            workshopPhone: workshopPhone,
            fullName: fullName,
            email: email
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: pendingDataKey)
        }
        pendingEmail = email
    }

    /// Obtiene los datos pendientes del workshop
    func getPendingWorkshopData() -> PendingWorkshopData? {
        guard let data = UserDefaults.standard.data(forKey: pendingDataKey),
              let pendingData = try? JSONDecoder().decode(PendingWorkshopData.self, from: data) else {
            return nil
        }
        return pendingData
    }

    /// Limpia los datos pendientes
    func clearPendingWorkshopData() {
        UserDefaults.standard.removeObject(forKey: pendingDataKey)
        pendingEmail = nil
    }

    /// Completa la creacion del workshop despues de la verificacion de email
    private func completePendingWorkshopCreation(data: PendingWorkshopData) async {
        guard let userId = user?.id else {
            print("❌ [Workshop] No hay usuario autenticado para completar workshop")
            return
        }

        print("🏭 [Workshop] ========== CREANDO WORKSHOP ==========")
        print("🏭 [Workshop] Usuario ID: \(userId)")
        print("🏭 [Workshop] Nombre taller: \(data.workshopName)")
        print("🏭 [Workshop] Teléfono: \(data.workshopPhone ?? "N/A")")
        print("🏭 [Workshop] Nombre completo: \(data.fullName)")

        do {
            // Verify we have a valid session before proceeding
            let session = try await supabase.client.auth.session
            print("🏭 [Workshop] Sesión verificada: \(session.user.id)")
            print("🏭 [Workshop] Access token presente: \(session.accessToken.prefix(20))...")

            // Call the secure function to create workshop and update profile
            print("🏭 [Workshop] Llamando función create_workshop_for_user...")

            struct CreateWorkshopParams: Encodable {
                let p_user_id: UUID
                let p_workshop_name: String
                let p_workshop_phone: String?
                let p_full_name: String?
            }

            let params = CreateWorkshopParams(
                p_user_id: userId,
                p_workshop_name: data.workshopName,
                p_workshop_phone: data.workshopPhone,
                p_full_name: data.fullName
            )

            let workshopId: UUID = try await supabase.client
                .rpc("create_workshop_for_user", params: params)
                .execute()
                .value

            print("✅ [Workshop] Workshop creado con ID: \(workshopId)")

            // Load the created workshop
            print("🏭 [Workshop] Cargando datos del workshop...")
            let newWorkshop: Workshop = try await supabase.client
                .from("workshops")
                .select()
                .eq("id", value: workshopId.uuidString)
                .single()
                .execute()
                .value

            print("✅ [Workshop] Workshop cargado: \(newWorkshop.name)")

            // 3. Update local state
            self.workshop = newWorkshop
            print("✅ [Workshop] Estado local actualizado")

            // 4. Clear pending data
            clearPendingWorkshopData()
            print("✅ [Workshop] Datos pendientes limpiados")

            // 5. Show onboarding for new workshop
            self.shouldShowOnboarding = true
            print("🏭 [Workshop] ========== WORKSHOP CREADO EXITOSAMENTE ==========")

        } catch {
            print("❌ [Workshop] ========== ERROR ==========")
            print("❌ [Workshop] Error: \(error)")
            print("❌ [Workshop] Descripción: \(error.localizedDescription)")
            // Keep pending data for retry
        }
    }

    /// Signup que guarda datos pendientes y crea el usuario
    func signUpWithPendingWorkshop(
        workshopName: String,
        workshopPhone: String?,
        fullName: String,
        email: String,
        password: String
    ) async throws {
        print("📝 [Signup] ========== INICIANDO REGISTRO ==========")
        print("📝 [Signup] Workshop: \(workshopName)")
        print("📝 [Signup] Teléfono: \(workshopPhone ?? "N/A")")
        print("📝 [Signup] Nombre: \(fullName)")
        print("📝 [Signup] Email: \(email)")

        // 1. Save pending data first
        print("📝 [Signup] Paso 1: Guardando datos pendientes en UserDefaults...")
        savePendingWorkshopData(
            workshopName: workshopName,
            workshopPhone: workshopPhone,
            fullName: fullName,
            email: email
        )
        print("✅ [Signup] Datos pendientes guardados")

        // 2. Create user account
        do {
            print("📝 [Signup] Paso 2: Creando cuenta en Supabase Auth...")
            let authResponse = try await supabase.client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )
            print("✅ [Signup] Usuario creado exitosamente!")
            print("   - User ID: \(authResponse.user.id)")
            print("   - Email: \(authResponse.user.email ?? "N/A")")
            print("   - Email confirmado: \(authResponse.user.emailConfirmedAt != nil)")
            print("📝 [Signup] ========== REGISTRO COMPLETADO ==========")
            print("📝 [Signup] El workshop se creará cuando handleAuthStateChange detecte signedIn")

            // If email confirmation is disabled, the user will be auto-signed in
            // and handleAuthStateChange will complete the workshop creation

        } catch {
            print("❌ [Signup] ========== ERROR EN REGISTRO ==========")
            print("❌ [Signup] Error: \(error)")
            print("❌ [Signup] Limpiando datos pendientes...")
            clearPendingWorkshopData()
            throw error
        }
    }

    /// Reenviar email de verificacion
    func resendVerificationEmail(to email: String) async throws {
        try await supabase.client.auth.resend(email: email, type: .signup)
        print("📧 Email de verificacion reenviado a: \(email)")
    }

    // MARK: - Deep Link Handling

    /// Maneja el deep link de confirmacion de email de Supabase
    func handleDeepLink(url: URL) async {
        print("🔗 Deep link recibido: \(url)")

        do {
            // Supabase SDK handles the verification automatically
            let session = try await supabase.client.auth.session(from: url)
            self.user = session.user
            print("✅ Sesion establecida desde deep link: \(session.user.id)")

            // The auth state change listener will handle the rest
            // including creating the workshop if there's pending data

        } catch {
            print("❌ Error procesando deep link: \(error)")
        }
    }
}

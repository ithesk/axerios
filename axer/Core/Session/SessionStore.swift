import Foundation
import Supabase
import os.log

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

    // Logger para debugging (solo visible en consola de desarrollo)
    private let logger = Logger(subsystem: "com.axer.app", category: "Session")

    func initialize() async {
        do {
            let session = try await supabase.client.auth.session
            self.user = session.user
            await loadUserData()

            // Check if we have pending workshop data to complete
            if let pendingData = getPendingWorkshopData() {
                await completePendingWorkshopCreation(data: pendingData)
            }

            state = .authenticated
        } catch {
            // Check if there's pending email verification
            if let pendingData = getPendingWorkshopData() {
                pendingEmail = pendingData.email
                state = .pendingEmailVerification
            } else {
                state = .unauthenticated
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
        switch state.event {
        case .signedIn:
            if let session = state.session {
                self.user = session.user

                // Check if we have pending workshop to create
                if let pendingData = getPendingWorkshopData() {
                    await completePendingWorkshopCreation(data: pendingData)
                }

                await loadUserData()
                self.state = .authenticated
            }
        case .signedOut:
            self.user = nil
            self.profile = nil
            self.workshop = nil
            self.state = .unauthenticated
        default:
            break
        }
    }

    func loadUserData() async {
        guard let userId = user?.id else {
            return
        }

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

            // Load workshop if profile has workshop_id
            if let workshopId = profileResponse.workshopId {
                let workshopResponse: Workshop = try await supabase.client
                    .from("workshops")
                    .select()
                    .eq("id", value: workshopId.uuidString)
                    .single()
                    .execute()
                    .value

                self.workshop = workshopResponse
            }
        } catch {
            #if DEBUG
            logger.error("Error loading user data: \(error.localizedDescription)")
            #endif
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
        // 1. Create user account
        let authResponse: AuthResponse
        do {
            authResponse = try await supabase.client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )
        } catch {
            throw error
        }

        let userId = authResponse.user.id

        // 2. Create workshop
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

            guard let workshop = workshopResponse.first else {
                throw AppError.invalidData
            }
            newWorkshop = workshop
        } catch {
            throw error
        }

        // 3. Update profile with workshop_id
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
        } catch {
            throw error
        }

        // 4. Update local state
        self.workshop = newWorkshop
        await loadUserData()
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
            throw AppError.unauthorized
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
    /// Usa Keychain para almacenamiento seguro
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
        do {
            try KeychainManager.save(data, forKey: pendingDataKey)
        } catch {
            #if DEBUG
            logger.error("Error saving pending workshop data to Keychain: \(error.localizedDescription)")
            #endif
        }
        pendingEmail = email
    }

    /// Obtiene los datos pendientes del workshop desde Keychain
    func getPendingWorkshopData() -> PendingWorkshopData? {
        do {
            return try KeychainManager.load(forKey: pendingDataKey)
        } catch {
            return nil
        }
    }

    /// Limpia los datos pendientes de Keychain
    func clearPendingWorkshopData() {
        try? KeychainManager.delete(forKey: pendingDataKey)
        pendingEmail = nil
    }

    /// Completa la creacion del workshop despues de la verificacion de email
    private func completePendingWorkshopCreation(data: PendingWorkshopData) async {
        guard let userId = user?.id else {
            return
        }

        do {
            // Verify we have a valid session before proceeding
            _ = try await supabase.client.auth.session

            // Call the secure function to create workshop and update profile
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

            // Load the created workshop
            let newWorkshop: Workshop = try await supabase.client
                .from("workshops")
                .select()
                .eq("id", value: workshopId.uuidString)
                .single()
                .execute()
                .value

            // Update local state
            self.workshop = newWorkshop

            // Clear pending data
            clearPendingWorkshopData()

            // Show onboarding for new workshop
            self.shouldShowOnboarding = true

        } catch {
            #if DEBUG
            logger.error("Error creating workshop: \(error.localizedDescription)")
            #endif
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
        // 1. Save pending data first
        savePendingWorkshopData(
            workshopName: workshopName,
            workshopPhone: workshopPhone,
            fullName: fullName,
            email: email
        )

        // 2. Create user account
        do {
            _ = try await supabase.client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )
            // If email confirmation is disabled, the user will be auto-signed in
            // and handleAuthStateChange will complete the workshop creation

        } catch {
            clearPendingWorkshopData()
            throw error
        }
    }

    /// Reenviar email de verificacion
    func resendVerificationEmail(to email: String) async throws {
        try await supabase.client.auth.resend(email: email, type: .signup)
    }

    // MARK: - Account Deletion

    /// Elimina la cuenta del usuario y todos sus datos asociados
    /// Requerido por Apple App Store Guidelines
    func deleteAccount() async throws {
        guard let userId = user?.id else {
            throw AppError.unauthorized
        }

        // Llamar a función RPC que elimina datos del usuario
        // Esta función debe existir en Supabase y manejar:
        // - Eliminar perfil
        // - Desasociar de workshop (o eliminar si es el único admin)
        // - Limpiar datos relacionados
        do {
            try await supabase.client
                .rpc("delete_user_account", params: ["p_user_id": userId.uuidString])
                .execute()
        } catch {
            #if DEBUG
            logger.error("Error deleting user data: \(error.localizedDescription)")
            #endif
            // Continuar con el signout aunque falle la limpieza de datos
        }

        // Limpiar datos locales
        clearPendingWorkshopData()

        // Cerrar sesión (esto también invalida el token)
        try await supabase.client.auth.signOut()

        // Limpiar estado local
        self.user = nil
        self.profile = nil
        self.workshop = nil
        self.state = .unauthenticated

        HapticManager.success()
    }

    // MARK: - Deep Link Handling

    /// Maneja el deep link de confirmacion de email de Supabase
    func handleDeepLink(url: URL) async {
        do {
            // Supabase SDK handles the verification automatically
            let session = try await supabase.client.auth.session(from: url)
            self.user = session.user
            // The auth state change listener will handle the rest
            // including creating the workshop if there's pending data

        } catch {
            #if DEBUG
            logger.error("Error processing deep link: \(error.localizedDescription)")
            #endif
        }
    }
}

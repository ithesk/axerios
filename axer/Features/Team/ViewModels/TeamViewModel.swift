import Foundation
import Supabase

@MainActor
final class TeamViewModel: ObservableObject {
    @Published var members: [TeamMember] = []
    @Published var invites: [Invite] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseClient.shared

    func loadTeam(workshopId: UUID) async {
        isLoading = true
        error = nil

        do {
            // Load team members
            let membersResponse: [TeamMember] = try await supabase.client
                .from("profiles")
                .select("id, full_name, role")
                .eq("workshop_id", value: workshopId.uuidString)
                .execute()
                .value

            self.members = membersResponse

            // Load pending invites
            let invitesResponse: [Invite] = try await supabase.client
                .from("invites")
                .select()
                .eq("workshop_id", value: workshopId.uuidString)
                .is("used_at", value: nil)
                .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
                .order("created_at", ascending: false)
                .execute()
                .value

            self.invites = invitesResponse

        } catch {
            self.error = "Error cargando equipo: \(error.localizedDescription)"
            print("Error loading team: \(error)")
        }

        isLoading = false
    }

    func createInvite(workshopId: UUID, role: UserRole) async -> Invite? {
        do {
            struct InviteInsert: Encodable {
                let workshop_id: UUID
                let role: String
            }

            let inviteData = InviteInsert(
                workshop_id: workshopId,
                role: role.rawValue
            )

            let response: [Invite] = try await supabase.client
                .from("invites")
                .insert(inviteData)
                .select()
                .execute()
                .value

            if let newInvite = response.first {
                invites.insert(newInvite, at: 0)
                return newInvite
            }
        } catch {
            self.error = "Error creando invitacion: \(error.localizedDescription)"
            print("Error creating invite: \(error)")
        }

        return nil
    }

    func deleteInvite(_ invite: Invite) async {
        do {
            try await supabase.client
                .from("invites")
                .delete()
                .eq("id", value: invite.id.uuidString)
                .execute()

            invites.removeAll { $0.id == invite.id }
        } catch {
            self.error = "Error eliminando invitacion"
            print("Error deleting invite: \(error)")
        }
    }

    // MARK: - Static methods for joining

    static func validateInvite(token: String) async -> InviteValidation? {
        do {
            let response: [InviteValidation] = try await SupabaseClient.shared.client
                .rpc("validate_invite", params: ["invite_token": token])
                .execute()
                .value

            return response.first
        } catch {
            print("Error validating invite: \(error)")
            return nil
        }
    }

    static func acceptInvite(token: String) async -> Bool {
        do {
            let response: Bool = try await SupabaseClient.shared.client
                .rpc("accept_invite", params: ["invite_token": token])
                .execute()
                .value

            return response
        } catch {
            print("Error accepting invite: \(error)")
            return false
        }
    }
}

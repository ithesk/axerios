import Foundation

@MainActor
final class CustomersViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    @Published var isLoading = false
    @Published var error: String?

    private let supabase = SupabaseClient.shared

    func filteredCustomers(searchText: String) -> [Customer] {
        if searchText.isEmpty {
            return customers
        }
        return customers.filter { customer in
            customer.name.localizedCaseInsensitiveContains(searchText) ||
            customer.phone?.localizedCaseInsensitiveContains(searchText) == true ||
            customer.email?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    func loadCustomers(workshopId: UUID) async {
        isLoading = true
        error = nil

        do {
            let response: [Customer] = try await supabase.client
                .from("customers")
                .select()
                .eq("workshop_id", value: workshopId.uuidString)
                .order("name")
                .execute()
                .value

            self.customers = response
        } catch {
            self.error = "Error cargando clientes: \(error.localizedDescription)"
            print("Error loading customers: \(error)")
        }

        isLoading = false
    }

    func createCustomer(
        workshopId: UUID,
        name: String,
        phone: String?,
        email: String?
    ) async -> Customer? {
        struct CustomerInsert: Encodable {
            let workshop_id: UUID
            let name: String
            let phone: String?
            let email: String?
        }

        do {
            let data = CustomerInsert(
                workshop_id: workshopId,
                name: name,
                phone: phone,
                email: email
            )

            let response: [Customer] = try await supabase.client
                .from("customers")
                .insert(data)
                .select()
                .execute()
                .value

            if let customer = response.first {
                customers.append(customer)
                customers.sort { $0.name < $1.name }
                return customer
            }
        } catch {
            self.error = "Error creando cliente: \(error.localizedDescription)"
            print("Error creating customer: \(error)")
        }

        return nil
    }

    func updateCustomer(
        customerId: UUID,
        name: String,
        phone: String?,
        email: String?,
        notes: String?
    ) async -> Bool {
        struct CustomerUpdate: Encodable {
            let name: String
            let phone: String?
            let email: String?
            let notes: String?
            let updated_at: String
        }

        do {
            let data = CustomerUpdate(
                name: name,
                phone: phone,
                email: email,
                notes: notes,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            try await supabase.client
                .from("customers")
                .update(data)
                .eq("id", value: customerId.uuidString)
                .execute()

            // Update local array
            if let index = customers.firstIndex(where: { $0.id == customerId }) {
                var updated = customers[index]
                updated.name = name
                updated.phone = phone
                updated.email = email
                updated.notes = notes
                customers[index] = updated
                customers.sort { $0.name < $1.name }
            }

            return true
        } catch {
            self.error = "Error actualizando cliente: \(error.localizedDescription)"
            print("Error updating customer: \(error)")
            return false
        }
    }

    func deleteCustomer(customerId: UUID) async -> Bool {
        do {
            try await supabase.client
                .from("customers")
                .delete()
                .eq("id", value: customerId.uuidString)
                .execute()

            customers.removeAll { $0.id == customerId }
            return true
        } catch {
            self.error = "Error eliminando cliente: \(error.localizedDescription)"
            print("Error deleting customer: \(error)")
            return false
        }
    }
}

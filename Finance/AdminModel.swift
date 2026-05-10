import ClientService
import FinanceCoreSDK
import Foundation
import LoggingSDK
import Observation

@Observable
@MainActor
final class AdminModel {
    var users: [AdminUserInfo] = []
    var reports: [ReviewItem] = []
    var errors: AdminErrorsResponse?
    var buildStatus: BuildStatusResponse?
    var isLoading = false
    var errorMessage: String?

    private let logger = Logger(label: "GetRicher.AdminModel")

    func loadUsers(backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: load users")
        do {
            users = try await APIClient(baseURL: backendURL).adminListUsers()
        } catch {
            logger.error("Admin: load users failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func deleteUser(username: String, backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: delete user \(username)")
        do {
            try await APIClient(baseURL: backendURL).adminDeleteUser(username: username)
            users.removeAll { $0.username == username }
        } catch {
            logger.error("Admin: delete user \(username) failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func updateLMToken(username: String, lmToken: String, backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: update LM token for \(username)")
        do {
            try await APIClient(baseURL: backendURL).adminUpdateLMToken(username: username, lmToken: lmToken)
        } catch {
            logger.error("Admin: update LM token for \(username) failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func loadReports(backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: load reports")
        do {
            reports = try await APIClient(baseURL: backendURL).adminListReports()
        } catch {
            logger.error("Admin: load reports failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func deleteReport(id: String, backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: delete report \(id)")
        do {
            try await APIClient(baseURL: backendURL).adminDeleteReport(id: id)
            reports.removeAll { $0.id == id }
        } catch {
            logger.error("Admin: delete report \(id) failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func loadBuildStatus(backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: load build status")
        do {
            buildStatus = try await APIClient(baseURL: backendURL).buildStatus()
        } catch {
            logger.error("Admin: load build status failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func generateReport(backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: generate report")
        do {
            _ = try await APIClient(baseURL: backendURL).generateReport()
        } catch {
            logger.error("Admin: generate report failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func loadErrors(backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: load errors")
        do {
            errors = try await APIClient(baseURL: backendURL).adminErrors()
        } catch {
            logger.error("Admin: load errors failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}

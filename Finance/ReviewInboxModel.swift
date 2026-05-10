import FinanceCoreSDK
import Foundation
import LoggingSDK
import Observation

@Observable
@MainActor
final class ReviewInboxModel {
    enum State {
        case idle
        case loading
        case loaded([ReviewItem])
        case error(String)
    }

    var state: State = .idle
    private let logger = Logger(label: "GetRicher.ReviewInboxModel")

    var items: [ReviewItem] {
        if case .loaded(let items) = state { return items }
        return []
    }

    func loadItems() async {
        guard let backendURL = UserDefaults.standard.string(forKey: "backendURL"),
              !backendURL.isEmpty,
              let url = URL(string: backendURL + "/api/review-items")
        else {
            state = .loaded([])
            return
        }
        logger.info("Load review items")
        state = .loading
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let items = try JSONDecoder().decode([ReviewItem].self, from: data)
            state = .loaded(items)
        } catch {
            logger.error("Load review items failed: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
        }
    }

    func resolve(_ item: ReviewItem, status: ReviewItem.Status) async {
        guard let backendURL = UserDefaults.standard.string(forKey: "backendURL"),
              !backendURL.isEmpty,
              let url = URL(string: backendURL + "/api/review-items/resolve")
        else { return }
        logger.info("Resolve item \(item.id) status=\(status.rawValue)")

        struct ResolveRequest: Encodable {
            let id: String
            let status: String
        }
        guard let body = try? JSONEncoder().encode(ResolveRequest(id: item.id, status: status.rawValue)) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        _ = try? await URLSession.shared.data(for: request)
        await loadItems()
    }
}

import FirebaseAuth

@MainActor final class AuthenticationService {
    static let shared = AuthenticationService()
    private init() {}

    func userID() async throws -> String {
        if let user = Auth.auth().currentUser { return user.uid }
        return try await Auth.auth().signInAnonymously().user.uid
    }
}

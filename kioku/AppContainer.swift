import SwiftData

enum AppContainer {
    static let shared: ModelContainer = {
        let schema = Schema([Note.self])
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}

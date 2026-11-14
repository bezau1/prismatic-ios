import Foundation

@MainActor
final class InstanceStore: ObservableObject {
    static let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Instances")
    @Published var instances: [Instance] = []
    private var indexURL: URL { Self.baseURL.appendingPathComponent("index.json") }

    init() {
        try? FileManager.default.createDirectory(at: Self.baseURL, withIntermediateDirectories: true)
        if let d = try? Data(contentsOf: indexURL),
           let list = try? JSONDecoder().decode([Instance].self, from: d) { instances = list }
    }
    func save() { try? JSONEncoder().encode(instances).write(to: indexURL) }
    func add(_ i: Instance) { instances.append(i); save() }
    func update(_ i: Instance) {
        if let n = instances.firstIndex(where: { $0.id == i.id }) { instances[n] = i; save() }
    }
    func delete(_ i: Instance) {
        try? FileManager.default.removeItem(at: i.root)
        instances.removeAll { $0.id == i.id }; save()
    }
}

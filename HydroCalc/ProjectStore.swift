import Foundation
import Combine

@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [HydroProject] = []
    @Published private(set) var loadBlocked = false
    @Published var errorKey: String?
    private let storage: HydroProjectStorage

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("HydroCalc", isDirectory: true)
        storage = HydroProjectStorage(url: directory.appendingPathComponent("projects.json"))
        reload()
    }

    func reload() {
        do {
            projects = try storage.load()
            loadBlocked = false
            errorKey = nil
        } catch {
            loadBlocked = true
            errorKey = "projects.loadError"
        }
    }

    @discardableResult
    func update(_ project: HydroProject) -> Bool {
        guard !loadBlocked else { return false }
        var proposed = projects
        if let index = proposed.firstIndex(where: { $0.id == project.id }) {
            proposed[index] = project
        } else { proposed.append(project) }
        return persist(proposed)
    }

    @discardableResult
    func delete(_ id: UUID) -> Bool {
        guard !loadBlocked else { return false }
        return persist(projects.filter { $0.id != id })
    }

    private func persist(_ proposed: [HydroProject]) -> Bool {
        do {
            try storage.save(proposed)
            projects = proposed
            return true
        } catch {
            errorKey = "projects.saveError"
            return false
        }
    }
}

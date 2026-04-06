import Foundation

actor SnapshotArchive {
    private struct ArchiveFile: Codable {
        var snapshots: [ObservedSnapshot]
    }

    private let fileURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appDirectory: URL

        if let groupDirectory = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: RidePressureShared.appGroupID
        ) {
            appDirectory = groupDirectory.appendingPathComponent("RidePressure", isDirectory: true)
        } else {
            let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            appDirectory = supportDirectory.appendingPathComponent("RidePressure", isDirectory: true)
        }

        self.fileURL = appDirectory.appendingPathComponent("snapshot-archive.json")
    }

    func latestSnapshot(for cityID: String) -> ObservedSnapshot? {
        loadArchive().snapshots
            .filter { $0.city.id == cityID }
            .sorted { $0.observedAt > $1.observedAt }
            .first
    }

    func recentRouteMedians(for cityID: String) -> [Double] {
        loadArchive().snapshots
            .filter { $0.city.id == cityID }
            .sorted { $0.observedAt > $1.observedAt }
            .compactMap { $0.routeObservation?.medianSecondsPerKm }
            .prefix(24)
            .map { $0 }
    }

    func recentProviderPrices(for cityID: String, provider: ProviderID) -> [Double] {
        loadArchive().snapshots
            .filter { $0.city.id == cityID }
            .sorted { $0.observedAt > $1.observedAt }
            .compactMap { snapshot in
                snapshot.providerSnapshots.first { $0.provider == provider }?.signals.priceAmount
            }
            .prefix(24)
            .map { $0 }
    }

    func save(_ snapshot: ObservedSnapshot) {
        var archive = loadArchive()
        archive.snapshots.removeAll { item in
            item.city.id == snapshot.city.id && item.observedAt == snapshot.observedAt
        }
        archive.snapshots.append(snapshot)
        archive.snapshots.sort { $0.observedAt > $1.observedAt }
        archive.snapshots = Array(archive.snapshots.prefix(240))
        writeArchive(archive)
    }

    private func loadArchive() -> ArchiveFile {
        do {
            guard fileManager.fileExists(atPath: fileURL.path) else {
                return ArchiveFile(snapshots: [])
            }
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(ArchiveFile.self, from: data)
        } catch {
            return ArchiveFile(snapshots: [])
        }
    }

    private func writeArchive(_ archive: ArchiveFile) {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(archive)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // If persistence fails, the app still works with live data.
        }
    }
}

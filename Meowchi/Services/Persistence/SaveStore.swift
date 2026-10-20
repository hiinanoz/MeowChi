import Foundation
import SwiftData

enum SaveStoreError: Error, Equatable {
    /// Neither the primary nor the backup payload could be read. The raw data was quarantined, not deleted.
    case corrupted
    case unsupportedVersion(Int)
}

protocol SaveStore {
    func load() throws -> GameState?
    func save(_ state: GameState) throws
}

/// Versioned JSON envelope. Keeping the state as one JSON payload gives us full control over migration.
enum SaveCodec {
    private struct Envelope: Codable {
        var version: Int
        var state: GameState
    }
    private struct VersionProbe: Decodable { var version: Int }

    static func encode(_ state: GameState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(Envelope(version: GameState.schemaVersion, state: state))
    }

    static func decode(_ data: Data) throws -> GameState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let version = try decoder.decode(VersionProbe.self, from: data).version
        guard version <= GameState.schemaVersion else { throw SaveStoreError.unsupportedVersion(version) }
        // Future: `case 1: migrate v1 -> v2` before decoding the current Envelope.
        var state = try decoder.decode(Envelope.self, from: data).state
        state.cat.stats.clamp()
        state.coins = max(0, state.coins)
        state.inventory = state.inventory.filter { $0.value > 0 }
        return state
    }
}

@Model
final class SaveRecord {
    @Attribute(.unique) var slot: String
    var schemaVersion: Int
    var payload: Data
    /// The previous good payload; used if `payload` is unreadable.
    var backupPayload: Data?
    var updatedAt: Date

    init(slot: String, schemaVersion: Int, payload: Data, updatedAt: Date) {
        self.slot = slot
        self.schemaVersion = schemaVersion
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

final class SwiftDataSaveStore: SaveStore {
    static let mainSlot = "main"
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    private func record(_ slot: String) throws -> SaveRecord? {
        var descriptor = FetchDescriptor<SaveRecord>(predicate: #Predicate { $0.slot == slot })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func load() throws -> GameState? {
        guard let record = try record(Self.mainSlot) else { return nil }
        if let state = try? SaveCodec.decode(record.payload) { return state }
        if let backup = record.backupPayload, let state = try? SaveCodec.decode(backup) { return state }
        // Keep the unreadable data for support/recovery, then free the main slot.
        let quarantine = SaveRecord(slot: "quarantine.\(Int(Date().timeIntervalSince1970))",
                                    schemaVersion: record.schemaVersion, payload: record.payload, updatedAt: .now)
        quarantine.backupPayload = record.backupPayload
        context.insert(quarantine)
        context.delete(record)
        try context.save()
        throw SaveStoreError.corrupted
    }

    func save(_ state: GameState) throws {
        let data = try SaveCodec.encode(state)
        if let record = try record(Self.mainSlot) {
            if (try? SaveCodec.decode(record.payload)) != nil { record.backupPayload = record.payload }
            record.payload = data
            record.schemaVersion = GameState.schemaVersion
            record.updatedAt = .now
        } else {
            context.insert(SaveRecord(slot: Self.mainSlot, schemaVersion: GameState.schemaVersion,
                                      payload: data, updatedAt: .now))
        }
        try context.save()
    }
}

/// Used by tests, previews and as a fallback when the on-disk store cannot be opened.
final class InMemorySaveStore: SaveStore {
    private(set) var data: Data?
    init(state: GameState? = nil) { data = state.flatMap { try? SaveCodec.encode($0) } }
    func load() throws -> GameState? { try data.map(SaveCodec.decode) }
    func save(_ state: GameState) throws { data = try SaveCodec.encode(state) }
}

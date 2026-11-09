import Foundation

/// Resolve persisted source identity independently of the paginated timeline cache.
enum NotebookSourceLookup {
    enum Kind: Sendable { case note, session, photo, segment }
    static func kind(_ id: UUID, database: DaybookDatabase) throws -> Kind? {
        let value: [DaybookDatabase.Value] = [.text(id.uuidString)]
        if try !database.query("SELECT 1 FROM content_segments WHERE id=? AND deleted=0",value).isEmpty { return .segment }
        if try !database.query("SELECT 1 FROM recording_sessions WHERE id=?",value).isEmpty { return .session }
        if try !database.query("SELECT 1 FROM voice_notes WHERE id=?",value).isEmpty { return .note }
        if try !database.query("SELECT 1 FROM photo_moments WHERE id=?",value).isEmpty { return .photo }
        return nil
    }
}

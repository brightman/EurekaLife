import Foundation
@main struct NotebookSourceSmoke {
    static func main() throws {
        let db=try DaybookDatabase(inMemory:true)
        let id=UUID()
        try db.execute("INSERT INTO recording_sessions(id,created_at) VALUES(?,?)",[.text(id.uuidString),.real(Date.now.timeIntervalSinceReferenceDate)])
        let sessionKind=try NotebookSourceLookup.kind(id,database:db); precondition(sessionKind == .session)
        try db.execute("DELETE FROM recording_sessions WHERE id=?",[.text(id.uuidString)])
        let missingKind=try NotebookSourceLookup.kind(id,database:db); precondition(missingKind == nil)
        let photo=UUID()
        try db.execute("INSERT INTO photo_moments(id,captured_at,caption,recognized_text) VALUES(?,?,?,?)",[.text(photo.uuidString),.real(0),.text("example"),.text("")])
        let photoKind=try NotebookSourceLookup.kind(photo,database:db); precondition(photoKind == .photo)
        let session=UUID(),segment=UUID(),key="session:"+session.uuidString
        try db.execute("INSERT INTO recording_sessions(id,created_at) VALUES(?,0)",[.text(session.uuidString)])
        try db.execute("INSERT INTO audio_processing_sources(source_key,kind,source_id,session_id,descriptor,fingerprint,configuration_key) VALUES(?,'session',?,?,?,'f','c')",[.text(key),.text(session.uuidString),.text(session.uuidString),.blob(Data())])
        try db.execute("INSERT INTO content_segments(id,source_key,start,revision,payload) VALUES(?,?,0,1,?)",[.text(segment.uuidString),.text(key),.blob(Data())])
        let segmentKind=try NotebookSourceLookup.kind(segment,database:db);precondition(segmentKind == .segment)
        try db.execute("UPDATE content_segments SET deleted=1 WHERE id=?",[.text(segment.uuidString)])
        let deletedSegment=try NotebookSourceLookup.kind(segment,database:db);precondition(deletedSegment == nil)
        print("Notebook source routing resolves durable session/photo kinds without UI cache; deleted sources return missing")
    }
}

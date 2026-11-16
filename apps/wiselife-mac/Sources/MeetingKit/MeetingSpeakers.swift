import Foundation

public struct MeetingSpeakerTurn: Codable, Sendable, Equatable {
    public var start: Double
    public var end: Double
    /// Empty means speech without a reliable identity; preserve it for overlap rejection.
    public var speakerID: String
    public init(start: Double, end: Double, speakerID: String) {
        self.start = start; self.end = end; self.speakerID = speakerID
    }
}

public struct MeetingSpeakerCheckpoint: Codable, Sendable {
    public var fingerprint: String
    public var completedWindows: Int = 0
    public var turns: [MeetingSpeakerTurn] = []
    public var features: [String: [Float]] = [:]
    public var nextSpeaker: Int = 1
    public init(fingerprint: String) { self.fingerprint = fingerprint }

    /// Windows are committed exactly once. Retry replays are harmless; gaps are errors.
    public mutating func append(window: Int, turns localTurns: [MeetingSpeakerTurn], features localFeatures: [String: [Float]]) throws {
        guard window >= 0 else { throw MeetingFailure.message("说话人分块编号无效。") }
        if window < completedWindows { return }
        guard window == completedWindows else { throw MeetingFailure.message("说话人分块不连续，检查点已保留。") }
        guard localTurns.allSatisfy({ $0.start.isFinite && $0.end.isFinite && $0.start >= 0 && $0.end > $0.start }) else {
            throw MeetingFailure.message("说话人时间区间无效，检查点已保留。")
        }
        let sorted = localTurns.sorted { $0.start == $1.start ? ($0.end == $1.end ? $0.speakerID < $1.speakerID : $0.end < $1.end) : $0.start < $1.start }
        var mapping: [String: String] = [:], claimed: Set<String> = []
        // Compare only to identities from earlier windows, never identities just created in this window.
        let prior = features
        for turn in sorted where mapping[turn.speakerID] == nil {
            mapping[turn.speakerID] = ""
            guard !turn.speakerID.isEmpty, let feature = Self.normalized(localFeatures[turn.speakerID]) else { continue }
            let candidates = prior.compactMap { id, values -> (String, Double)? in
                guard let reference = Self.normalized(values), reference.count == feature.count else { return nil }
                return (id, zip(feature, reference).reduce(0) { $0 + Double($1.0) * Double($1.1) })
            }.sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
            if let best = candidates.first, best.1 >= 0.90 {
                let second = candidates.dropFirst().first?.1 ?? -1
                guard best.1 - second >= 0.10, !claimed.contains(best.0) else { continue }
                mapping[turn.speakerID] = best.0; claimed.insert(best.0)
                // Keep the first reliable prototype: avoid cumulative centroid drift.
            } else {
                // Conservative, uncalibrated novelty boundary: near matches remain unknown.
                guard (candidates.first?.1 ?? -1) < 0.80 else { continue }
                let id = "speaker-\(nextSpeaker)"; nextSpeaker += 1
                mapping[turn.speakerID] = id; features[id] = feature; claimed.insert(id)
            }
        }
        turns.append(contentsOf: sorted.map { .init(start: $0.start, end: $0.end, speakerID: mapping[$0.speakerID] ?? "") })
        completedWindows += 1
    }

    private static func normalized(_ values: [Float]?) -> [Float]? {
        guard let values, !values.isEmpty, values.allSatisfy(\.isFinite) else { return nil }
        let norm = sqrt(values.reduce(0.0) { $0 + Double($1) * Double($1) })
        guard norm.isFinite, norm > 1e-8 else { return nil }
        return values.map { Float(Double($0) / norm) }
    }
}

public struct MeetingSpeakerSnapshot: Codable, Sendable {
    public var revision: UUID
    public var fingerprint: String
    public var assignments: [String: String]
    public var names: [String: String]
    public var previousNames: [String]
    public var turns: [MeetingSpeakerTurn]
    public var completedAt: Date

    public init(checkpoint: MeetingSpeakerCheckpoint, segments: [MeetingTranscriptSegment], previousNames: [String] = []) {
        revision = UUID(); fingerprint = checkpoint.fingerprint; names = [:]
        self.previousNames = previousNames; turns = checkpoint.turns; completedAt = Date()
        assignments = [:]
        for segment in segments {
            if let id = Self.identity(for: segment, turns: turns) { assignments[segment.id] = id }
        }
    }
    public func displayName(_ id: String) -> String {
        if let name = names[id], !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return name }
        if id.hasPrefix("speaker-"), let number = Int(id.dropFirst(8)), number > 0 { return "说话人\(number)" }
        return "未确定"
    }
    private static func identity(for segment: MeetingTranscriptSegment, turns: [MeetingSpeakerTurn]) -> String? {
        guard segment.start.isFinite, segment.end.isFinite, segment.end > segment.start else { return nil }
        let clipped = turns.compactMap { turn -> MeetingSpeakerTurn? in
            guard turn.start.isFinite, turn.end.isFinite else { return nil }
            let start = max(segment.start, turn.start), end = min(segment.end, turn.end)
            return end > start ? .init(start: start, end: end, speakerID: turn.speakerID) : nil
        }
        // Sweep unique interval boundaries so repeated same-speaker turns never double-count.
        let boundaries = Array(Set(clipped.flatMap { [$0.start, $0.end] })).sorted()
        guard boundaries.count > 1 else { return nil }
        var durations: [String: Double] = [:], covered = 0.0
        for index in 1..<boundaries.count {
            let start = boundaries[index - 1], end = boundaries[index]
            let active = Set(clipped.filter { $0.start < end && $0.end > start }.map(\.speakerID))
            // Any cross-speaker overlap, including unknown speech, makes this whole original row unknown.
            if active.count > 1 { return nil }
            if let id = active.first { durations[id, default: 0] += end - start; covered += end - start }
        }
        let candidates = durations.filter { !$0.key.isEmpty }.sorted { $0.value > $1.value }
        guard covered / (segment.end - segment.start) >= 0.60, let best = candidates.first,
              best.value / covered >= 0.80 else { return nil }
        let runnerUp = candidates.dropFirst().first?.value ?? 0
        guard (best.value - runnerUp) / covered >= 0.10 else { return nil }
        return best.key
    }
}

public enum MeetingSpeakerState: String, Codable, Sendable {
    case idle, running, ready, interrupted, failed, waitingForModel
}
public struct MeetingSpeakerDocument: Codable, Sendable {
    public var schemaVersion: Int = 1
    public var state: MeetingSpeakerState = .idle
    public var failure: String?
    public var result: MeetingSpeakerSnapshot?
    public var checkpoint: MeetingSpeakerCheckpoint?
    public init() {}
    public func currentResult(fingerprint: String) -> MeetingSpeakerSnapshot? {
        result?.fingerprint == fingerprint ? result : nil
    }
}

import Foundation

struct SpeakerWindowPlan: Sendable {
    let index: Int
    let coreStart: Double
    let coreEnd: Double
    let inputStart: Double
    let inputEnd: Double

    static func windows(duration: Double, startWindow: Int) throws -> [Self] {
        guard duration.isFinite, duration > 0, duration < Double(Int.max / 16_000) else {
            throw MeetingSpeakerError.invalidAudio
        }
        let count = Int(ceil(duration / 300))
        guard startWindow >= 0, startWindow <= count else { throw MeetingSpeakerError.invalidResumePoint }
        return (startWindow..<count).map { index in
            let start = Double(index) * 300, end = min(duration, start + 300)
            return Self(index: index, coreStart: start, coreEnd: end,
                        inputStart: max(0, start - 2), inputEnd: min(duration, end + 2))
        }
    }

    func project(_ turns: [SpeakerLocalTurn]) throws -> [SpeakerLocalTurn] {
        try turns.compactMap { turn in
            guard turn.start.isFinite, turn.end.isFinite, turn.start >= 0,
                  turn.end >= turn.start, turn.end <= inputEnd - inputStart + 1 else {
                throw MeetingSpeakerError.invalidTimestamp
            }
            let start = max(coreStart, inputStart + turn.start)
            let end = min(coreEnd, inputStart + turn.end)
            guard end > start, !turn.speakerID.isEmpty else { return nil }
            return .init(start: start, end: end, speakerID: turn.speakerID)
        }
    }
}

/// Selection matches the iPhone policy: only the union of exclusive speech is
/// eligible. Silence, gaps and simultaneous other speakers never enter features.
enum SpeakerFeaturePolicy {
    static func soloRanges(turns: [SpeakerLocalTurn], speakerID: String, sampleCount: Int) -> [Range<Int>] {
        struct Edge { let sample: Int; let speaker: String; let delta: Int }
        var edges: [Edge] = []
        for turn in turns where turn.start.isFinite && turn.end.isFinite && turn.end > turn.start {
            let start = Int(min(Double(sampleCount), max(0, ceil(turn.start * 16_000))))
            let end = Int(min(Double(sampleCount), max(0, floor(turn.end * 16_000))))
            guard end > start else { continue }
            edges.append(.init(sample: start, speaker: turn.speakerID, delta: 1))
            edges.append(.init(sample: end, speaker: turn.speakerID, delta: -1))
        }
        edges.sort { $0.sample < $1.sample }
        var active: [String: Int] = [:], previous = 0
        var result: [Range<Int>] = []
        for edge in edges {
            if edge.sample > previous, active.count == 1, active[speakerID] != nil {
                if let last = result.last, last.upperBound == previous { result[result.count - 1] = last.lowerBound..<edge.sample }
                else { result.append(previous..<edge.sample) }
            }
            let count = (active[edge.speaker] ?? 0) + edge.delta
            active[edge.speaker] = count > 0 ? count : nil
            previous = edge.sample
        }
        return result
    }

    /// At most three ten-second inputs per cluster, bounded even on a long window.
    static func samples(_ samples: [Float], ranges: [Range<Int>]) -> [[Float]] {
        var selected: [Float] = []
        selected.reserveCapacity(480_000)
        for range in ranges {
            let start = max(0, range.lowerBound), end = min(samples.count, range.upperBound)
            guard end > start else { continue }
            selected.append(contentsOf: samples[start..<min(end, start + 480_000 - selected.count)])
            if selected.count == 480_000 { break }
        }
        guard selected.count >= 32_000 else { return [] }
        // Retain the model's full real-speech context. Balancing a 20.1s turn
        // into three 6.7s samples needlessly shortens every embedding because
        // of a tiny segmenter tail. Keep complete 10s inputs and useful tails.
        return stride(from: 0, to: selected.count, by: 160_000).map { start in
            Array(selected[start..<min(selected.count, start + 160_000)])
        }.filter(usable)
    }

    static func usable(_ samples: [Float]) -> Bool {
        (32_000...160_000).contains(samples.count) && samples.allSatisfy { $0.isFinite && abs($0) <= 1 }
            && samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count) > 1e-8
    }

    static func normalized(_ vector: [Float]) throws -> [Float] {
        guard vector.count == 256, vector.allSatisfy(\.isFinite) else { throw MeetingSpeakerError.invalidFeature }
        let norm = sqrt(vector.reduce(0.0) { $0 + Double($1) * Double($1) })
        guard norm.isFinite, norm > 1e-12 else { throw MeetingSpeakerError.invalidFeature }
        return vector.map { Float(Double($0) / norm) }
    }

    static func consensus(_ vectors: [[Float]]) -> [Float]? {
        guard !vectors.isEmpty else { return nil }
        guard let normalized = try? vectors.map({ try Self.normalized($0) }) else { return nil }
        for i in normalized.indices {
            for j in normalized.indices where j > i {
                let cosine = zip(normalized[i], normalized[j]).reduce(0.0) { $0 + Double($1.0) * Double($1.1) }
                guard cosine >= 0.90 else { return nil }
            }
        }
        return try? Self.normalized((0..<256).map { column in normalized.reduce(Float(0)) { $0 + $1[column] } })
    }
}

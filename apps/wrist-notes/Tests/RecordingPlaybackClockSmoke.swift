import Foundation

@main struct RecordingPlaybackClockSmoke {
    static func main() throws {
        let parser = ISO8601DateFormatter()
        let sourceStart = parser.date(from: "2026-11-02T06:00:10Z")!
        let zone = TimeZone(secondsFromGMT: 8 * 3600)!
        let file = URL(fileURLWithPath: "/fixture/recording.m4a")
        // The second range follows a 50-second gap; compact playback skips it.
        let ranges: [RecordingSourceRange] = [
            .init(chunkID: UUID(), url: file, startFrame: 48_000, endFrame: 208_000,
                  sampleRate: 16_000, sessionStartOffset: 1920),
            .init(chunkID: UUID(), url: file, startFrame: 0, endFrame: 320_000,
                  sampleRate: 16_000, sessionStartOffset: 1980, discontinuityBefore: "missingChunks")
        ]
        let plan = try RecordingRangePlan(ranges)
        let segmentStart = plan.recordingDate(at: 0, startedAt: sourceStart)!
        func label(_ seconds: Double) -> String {
            RecordingFormat.recordedTime(plan.recordingDate(at: seconds, startedAt: sourceStart)!,
                                         relativeTo: segmentStart, timeZone: zone)
        }
        precondition(label(0) == "14:32:10", "A trimmed segment starts at its real capture time, not zero or the source start")
        precondition(label(5) == "14:32:15", "Frame trims must not be added to source offsets twice")
        precondition(label(9.9) == "14:32:19", "Fractional playback positions do not round forward")
        precondition(label(10) == "14:33:10", "The range boundary jumps across the real capture gap")
        precondition(label(15) == "14:33:15")
        precondition(label(30) == "14:33:30", "The exact endpoint shows the actual final recording time")
        precondition(label(90) == "14:33:30" && label(-5) == "14:32:10", "Out-of-range seek labels clamp to the recording")
        precondition(plan.recordingDate(at: .nan, startedAt: sourceStart) == nil)
        precondition(plan.recordingDate(at: .infinity, startedAt: sourceStart) == nil)
        let empty = try RecordingRangePlan([])
        precondition(empty.recordingDate(at: 0, startedAt: sourceStart) == nil)
        let midnightStart = parser.date(from: "2026-12-31T15:59:55Z")!
        precondition(RecordingFormat.recordedTime(midnightStart, relativeTo: midnightStart, timeZone: zone) == "23:59:55")
        precondition(RecordingFormat.recordedTime(midnightStart.addingTimeInterval(10), relativeTo: midnightStart,
                                                 timeZone: zone) == "01-01 00:00:05", "Cross-midnight clocks include the new date")
        precondition(plan.locate(15)?.frame == 80_000 && plan.duration == 30,
                     "Wall-clock presentation preserves compact playback duration and seek frames")
        print("Recording playback clock passed: trimmed ranges, gaps, endpoints, invalid input and midnight")
    }
}

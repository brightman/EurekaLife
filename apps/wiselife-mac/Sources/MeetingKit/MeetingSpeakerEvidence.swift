import Foundation

/// Bounded original quotations with current, validated labels. No historical names
/// or saved summary is used to infer who spoke.
public struct MeetingSpeakerEvidence: Sendable {
    public let text: String
    public let scope: String

    public static func make(segments: [MeetingTranscriptSegment], result: MeetingSpeakerSnapshot,
                            question: String, maximumBytes: Int = 4200) -> MeetingSpeakerEvidence {
        let named = matchingSpeakers(question, result: result)
        let eligible = segments.filter { named.isEmpty || named.contains(result.assignments[$0.id] ?? "") }
        let query = terms(question)
        var ranked: [(Int, MeetingTranscriptSegment, Int)] = []
        for (offset, segment) in eligible.enumerated() {
            ranked.append((offset, segment, query.intersection(terms(segment.text)).count))
        }
        ranked.sort { lhs, rhs in lhs.2 == rhs.2 ? lhs.0 < rhs.0 : lhs.2 > rhs.2 }
        // With no lexical signal, sample across the recording instead of presenting
        // only its opening as if it represented the entire meeting.
        let candidates: [MeetingTranscriptSegment]
        if (ranked.first?.2 ?? 0) > 0 { candidates = ranked.map { $0.1 } }
        else {
            let count = min(eligible.count, max(1, maximumBytes / 500))
            candidates = (0..<count).map { eligible[count == 1 ? 0 : $0 * (eligible.count - 1) / (count - 1)] }
        }
        var selected: [(Double, String)] = []
        var remaining = max(0, maximumBytes)
        for segment in candidates {
            let name = result.assignments[segment.id].map { result.displayName($0) } ?? "未确定"
            let prefix = "[\(MeetingAnalysis.timestamp(segment.start))] \(name)："
            let allowance = min(700, remaining - prefix.utf8.count - (selected.isEmpty ? 0 : 1))
            guard allowance > 8 else { continue }
            let body = clipped(segment.text, bytes: allowance)
            guard !body.isEmpty else { continue }
            let line = prefix + body
            remaining -= line.utf8.count + (selected.isEmpty ? 0 : 1)
            selected.append((segment.start, line))
        }
        return .init(text: selected.sorted { $0.0 < $1.0 }.map { $0.1 }.joined(separator: "\n"),
                     scope: "当前说话人标注的会议原文选段，不能代表全部发言；未确定表示归属不可靠，未选入的内容不能断言未提及")
    }

    private static func matchingSpeakers(_ question: String, result: MeetingSpeakerSnapshot) -> Set<String> {
        let source = question as NSString
        var matches: [(String, NSRange)] = []
        for id in Set(result.assignments.values) {
            let label = result.displayName(id)
            let suffix = result.names[id] == nil ? "(?![0-9])" : ""
            guard let pattern = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: label) + suffix, options: [.caseInsensitive]) else { continue }
            matches += pattern.matches(in: question, range: NSRange(location: 0, length: source.length)).map { (id, $0.range) }
        }
        // A longer person's name owns its whole span; a short prefix must not
        // accidentally include another speaker. Equal names remain ambiguous.
        return Set(matches.filter { candidate in
            !matches.contains { other in other.1.length > candidate.1.length && NSIntersectionRange(other.1, candidate.1).length == candidate.1.length }
        }.map { $0.0 })
    }

    private static func clipped(_ value: String, bytes: Int) -> String {
        guard value.utf8.count > bytes else { return value }
        var result = "", count = 0
        for character in value {
            let size = String(character).utf8.count
            guard count + size <= bytes - 3 else { break }
            result.append(character); count += size
        }
        return result + "…"
    }
    private static func terms(_ value: String) -> Set<String> {
        let words = value.lowercased().components(separatedBy: .alphanumerics.inverted).filter { $0.count > 1 }
        var result = Set(words)
        for word in words where word.unicodeScalars.contains(where: { $0.value >= 0x3400 && $0.value <= 0x9fff }) {
            let chars = Array(word)
            for index in 0..<max(0, chars.count - 1) { result.insert(String(chars[index...index + 1])) }
        }
        return result
    }
}

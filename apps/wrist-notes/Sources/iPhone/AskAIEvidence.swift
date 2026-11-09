import Foundation
import CryptoKit

// MARK: - Versioned cross-domain contracts

enum AgentEvidenceDomain: String, Codable, CaseIterable, Sendable { case timeline, ideas, ledger, people, places, conversation }
enum AgentDisclosurePolicy: String, Codable, Sendable { case localOnly, allowedRemote }

struct AgentNotebookPermissions: Codable, Equatable, Sendable {
    var allowIdeas = false
    var allowLedger = false
    var allowPeople = false
    var allowPlaces = false
    var allowedDomains: Set<AgentEvidenceDomain> {
        var result: Set<AgentEvidenceDomain> = [.timeline, .conversation]
        if allowIdeas { result.insert(.ideas) }; if allowLedger { result.insert(.ledger) }
        if allowPeople { result.insert(.people) }; if allowPlaces { result.insert(.places) }
        return result
    }
    var digest: String { SHA256.hash(data: Data(allowedDomains.map(\.rawValue).sorted().joined(separator: ",").utf8)).map { String(format: "%02x", $0) }.joined() }
}

struct AgentQueryScope: Codable, Equatable, Sendable {
    var domains: Set<AgentEvidenceDomain> = [.timeline, .conversation]
    var allowedKinds: Set<DayRecord.Kind> = []
    var dateRange: DateInterval? = nil
    var entityIDs: [String] = []
    var destination: AgentDisclosurePolicy = .localOnly
}

struct AgentEvidenceDependency: Codable, Equatable, Hashable, Sendable {
    let domain: AgentEvidenceDomain
    let entityID: String
    let revision: String
}

struct AgentEvidenceRef: Codable, Equatable, Sendable, Identifiable {
    let domain: AgentEvidenceDomain
    let entityID: String
    let number: Int
    let title: String
    let snippet: String
    let revision: String
    var querySpecification: String? = nil
    var dependencies: [AgentEvidenceDependency] = []
    var disclosurePolicy: AgentDisclosurePolicy = .localOnly
    var sourceKinds: Set<DayRecord.Kind> = []
    var excerptRange: String? = nil
    var id: String { domain.rawValue + ":" + entityID }
    var isValid: Bool {
        number > 0 && !entityID.isEmpty && entityID.utf8.count <= 512 && !entityID.contains("\0") &&
        !revision.isEmpty && revision.utf8.count <= 512 && title.count <= 120 && snippet.count <= 500 &&
        (querySpecification?.utf8.count ?? 0) <= 4096 && dependencies.count <= 64 &&
        dependencies.allSatisfy { !$0.entityID.isEmpty && $0.entityID.utf8.count <= 512 && $0.revision.utf8.count <= 512 } &&
        (excerptRange?.utf8.count ?? 0) <= 128
    }
}

/// Conservative authority of everything supplied during a run, independent of display citations.
struct AgentRunProvenance: Codable, Equatable, Sendable {
    var domains: Set<AgentEvidenceDomain> = []
    var sourceKinds: Set<DayRecord.Kind> = []
    var disclosurePolicy: AgentDisclosurePolicy = .allowedRemote
    var refs: [AgentEvidenceRef] = []
    var dependencies: [AgentEvidenceDependency] = []
    var historyTurnDigests: [String:String] = [:]
    var isValid: Bool { refs.count <= 128 && dependencies.count <= 512 && historyTurnDigests.count <= 128 && refs.allSatisfy(\.isValid) && dependencies.allSatisfy { !$0.entityID.isEmpty && $0.entityID.utf8.count <= 512 && !$0.entityID.contains("\0") && !$0.revision.isEmpty && $0.revision.utf8.count <= 512 && !$0.revision.contains("\0") } && historyTurnDigests.allSatisfy { UUID(uuidString:$0.key) != nil && $0.value.count == 64 } }
    func permits(_ scope: AgentQueryScope) -> Bool {
        domains.isSubset(of:scope.domains) && sourceKinds.isSubset(of:scope.allowedKinds) && (scope.destination == .localOnly || disclosurePolicy == .allowedRemote)
    }
    mutating func merge(_ other: Self) {
        domains.formUnion(other.domains);sourceKinds.formUnion(other.sourceKinds)
        if other.disclosurePolicy == .localOnly { disclosurePolicy = .localOnly }
        for ref in other.refs where !refs.contains(ref) { refs.append(ref) }
        dependencies = Array(Set(dependencies + other.dependencies)).sorted { ($0.domain.rawValue,$0.entityID,$0.revision) < ($1.domain.rawValue,$1.entityID,$1.revision) }
        for (id,digest) in other.historyTurnDigests {
            if let prior=historyTurnDigests[id],prior != digest { disclosurePolicy = .localOnly; historyTurnDigests[id] = "conflicting-history-revisions" }
            else { historyTurnDigests[id] = digest }
        }
    }
    static func evidence(_ refs:[AgentEvidenceRef]) -> Self {
        .init(domains:Set(refs.map(\.domain) + refs.flatMap { $0.dependencies.map(\.domain) }),sourceKinds:Set(refs.flatMap(\.sourceKinds)),disclosurePolicy:refs.contains { $0.disclosurePolicy == .localOnly } ? .localOnly : .allowedRemote,refs:refs,dependencies:Array(Set(refs.flatMap { [.init(domain:$0.domain,entityID:$0.entityID,revision:$0.revision)] + $0.dependencies })))
    }

}

import Foundation

private enum VerificationFailure: Error {
    case invalidStorage
    case invalidSystem
    case invalidDuplicateScan
    case cleanupWasPreparedUnexpectedly
}

@main
enum MacMaintenanceAgentVerifier {
    @MainActor
    static func main() async {
        do {
            let agent = MacMaintenanceAgentService.shared
            let storage = await agent.execute(.inspectStorage, arguments: nil)
            guard Int64(storage.facts["total_bytes"] ?? "0") ?? 0 > 0 else {
                throw VerificationFailure.invalidStorage
            }

            let system = await agent.execute(.inspectSystem, arguments: nil)
            guard Int(system.facts["processor_count"] ?? "0") ?? 0 > 0,
                  Int64(system.facts["physical_memory_bytes"] ?? "0") ?? 0 > 0 else {
                throw VerificationFailure.invalidSystem
            }

            let junk = await agent.execute(
                .scanJunk,
                arguments: .init(minimumSizeMB: nil, olderThanDays: 30)
            )
            guard junk.tool == .scanJunk else {
                throw VerificationFailure.invalidSystem
            }

            guard agent.pendingCleanup.isEmpty else {
                throw VerificationFailure.cleanupWasPreparedUnexpectedly
            }

            let duplicateFixture = FileManager.default.temporaryDirectory
                .appendingPathComponent("macoptimizer-agent-duplicate-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: duplicateFixture, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: duplicateFixture) }
            let repeated = Data(repeating: 0x5A, count: 2_048)
            try repeated.write(to: duplicateFixture.appendingPathComponent("copy-a.bin"))
            try repeated.write(to: duplicateFixture.appendingPathComponent("copy-b.bin"))
            try Data(repeating: 0x3C, count: 2_048).write(to: duplicateFixture.appendingPathComponent("different.bin"))
            let duplicates = MacMaintenanceAgentService.duplicateReport(in: [duplicateFixture])
            guard duplicates.count == 1,
                  duplicates.bytes == 2_048,
                  duplicates.facts["duplicate_groups"] == "1" else {
                throw VerificationFailure.invalidDuplicateScan
            }
            print("Mac maintenance agent verification passed (storage, system, junk, and SHA-256 duplicate tools; no cleanup executed).")
        } catch {
            fputs("Mac maintenance agent verification failed: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
}

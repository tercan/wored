import Foundation
import Darwin

@main
struct SingleInstanceLockTests {
    static func main() throws {
        if CommandLine.arguments.count == 3 {
            let lock = SingleInstanceLock()
            let acquired = try lock.acquire(at: URL(fileURLWithPath: CommandLine.arguments[2]))
            if CommandLine.arguments[1] == "hold", acquired {
                FileHandle.standardOutput.write(Data([1]))
                _ = withExtendedLifetime(lock) { pause() }
            }
            exit(acquired ? 0 : 1)
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("instance.lock")
        try checkContention(at: url)
        precondition(tryProbe(url) == 0, "Lock must be released when its owner is destroyed")

        let holder = makeProcess("hold", url)
        let ready = Pipe()
        holder.standardOutput = ready
        try holder.run()
        precondition(ready.fileHandleForReading.readData(ofLength: 1) == Data([1]))
        precondition(tryProbe(url) == 1, "A separate process must own the lock")
        kill(holder.processIdentifier, SIGKILL)
        holder.waitUntilExit()
        precondition(tryProbe(url) == 0, "A crash must release the lock without deleting its file")
        precondition(FileManager.default.fileExists(atPath: url.path))

        do {
            _ = try SingleInstanceLock().acquire(at: directory.appendingPathComponent("missing/instance.lock"))
            fatalError("File errors must not be treated as a competing instance")
        } catch is POSIXError {}
        print("PASS: exclusive ownership, repeated acquisition, process contention, normal release, crash recovery, file errors")
    }

    private static func checkContention(at url: URL) throws {
        let lock = SingleInstanceLock()
        let firstAcquisition = try lock.acquire(at: url)
        let repeatedAcquisition = try lock.acquire(at: url)
        precondition(firstAcquisition && repeatedAcquisition)
        let contenders = (0..<8).map { _ in makeProcess("probe", url) }
        for process in contenders { try process.run() }
        for process in contenders {
            process.waitUntilExit()
            precondition(process.terminationStatus == 1, "Only one process may acquire the lock")
        }
        withExtendedLifetime(lock) {}
    }

    private static func makeProcess(_ mode: String, _ url: URL) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = [mode, url.path]
        return process
    }

    private static func tryProbe(_ url: URL) -> Int32 {
        let process = makeProcess("probe", url)
        do { try process.run() } catch { fatalError("Failed to launch probe: \(error)") }
        process.waitUntilExit()
        return process.terminationStatus
    }
}

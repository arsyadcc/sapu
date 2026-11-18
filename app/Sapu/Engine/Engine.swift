import Foundation

/// Runs commands of the bundled cleanup engine (the upstream Mole CLI) as child processes.
nonisolated struct Engine: Sendable {
    enum Failure: LocalizedError {
        case missing(URL)
        case exited(Int32, String)

        var errorDescription: String? {
            switch self {
            case .missing(let url):
                "The cleanup engine was not found at \(url.path). Rebuild the app."
            case .exited(let code, let output):
                "The engine exited with status \(code).\n\(output.suffix(800))"
            }
        }
    }

    let root: URL

    var entrypoint: URL { root.appending(path: "mole") }

    static var bundled: Engine {
        Engine(root: Bundle.main.resourceURL!.appending(path: "engine"))
    }

    /// Runs a command to completion and returns its standard output.
    @concurrent
    func output(_ arguments: [String]) async throws -> Data {
        let process = try makeProcess(arguments)
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        let handle = ProcessHandle(process)
        return try await withTaskCancellationHandler {
            try process.run()
            let data = try stdout.fileHandleForReading.readToEnd() ?? Data()
            let errors = try stderr.fileHandleForReading.readToEnd() ?? Data()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw Failure.exited(process.terminationStatus, String(decoding: errors, as: UTF8.self))
            }
            return data
        } onCancel: {
            handle.terminate()
        }
    }

    /// Runs a command and yields its combined output line by line, with ANSI escapes removed.
    func lines(_ arguments: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process: Process
            do {
                process = try makeProcess(arguments)
            } catch {
                continuation.finish(throwing: error)
                return
            }
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.standardInput = FileHandle.nullDevice
            let handle = ProcessHandle(process)

            let reader = Task.detached {
                do {
                    try handle.process.run()
                    var tail: [String] = []
                    for try await line in pipe.fileHandleForReading.bytes.lines {
                        let clean = line.strippingANSI
                        tail.append(clean)
                        if tail.count > 20 { tail.removeFirst() }
                        continuation.yield(clean)
                    }
                    handle.process.waitUntilExit()
                    let status = handle.process.terminationStatus
                    if status == 0 {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: Failure.exited(status, tail.joined(separator: "\n")))
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                reader.cancel()
                handle.terminate()
            }
        }
    }

    private func makeProcess(_ arguments: [String]) throws -> Process {
        guard FileManager.default.isExecutableFile(atPath: entrypoint.path) else {
            throw Failure.missing(entrypoint)
        }
        let process = Process()
        process.executableURL = entrypoint
        process.arguments = arguments
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        var environment = ProcessInfo.processInfo.environment
        environment["NO_COLOR"] = "1"
        environment["TERM"] = "dumb"
        // GUI apps start with a minimal PATH; the engine expects the usual tool locations.
        let extraPath = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        environment["PATH"] = (extraPath + [environment["PATH"] ?? ""]).joined(separator: ":")
        process.environment = environment
        return process
    }
}

/// Lets cancellation handlers terminate a running process from any thread.
/// `Process.terminate()` and `isRunning` are safe to call concurrently.
nonisolated final class ProcessHandle: @unchecked Sendable {
    let process: Process

    init(_ process: Process) { self.process = process }

    func terminate() {
        if process.isRunning { process.terminate() }
    }
}

nonisolated extension String {
    var strippingANSI: String {
        replacing(/\u{1B}\[[0-9;?]*[ -\/]*[@-~]/, with: "")
    }
}

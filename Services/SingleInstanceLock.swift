import Foundation
import Darwin

final class SingleInstanceLock {
    private var descriptor: Int32 = -1

    func acquire(at url: URL) throws -> Bool {
        guard descriptor == -1 else { return true }
        let candidate = open(url.path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard candidate >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard flock(candidate, LOCK_EX | LOCK_NB) == 0 else {
            let errorCode = errno
            close(candidate)
            if errorCode == EWOULDBLOCK { return false }
            throw POSIXError(POSIXErrorCode(rawValue: errorCode) ?? .EIO)
        }
        // The OS releases the lock on exit, including crashes. Never unlink the file.
        descriptor = candidate
        return true
    }

    deinit {
        if descriptor >= 0 { close(descriptor) }
    }
}

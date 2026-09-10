import Foundation

class ConcurrentQueueFileStorageDecorator: FileStorage {
    private let concurrentQueue: DispatchQueue!
    private let decoratee: FileStorage

    init(queueName: String, decoratee: FileStorage) {
        self.concurrentQueue = DispatchQueue(label: queueName, attributes: .concurrent)
        self.decoratee = decoratee
    }

    // WRITES should be asynchronous and use a `barrier`
    func write<T: Encodable>(
        payload: T,
        to fileURL: URL,
        options: [RoktDownloadOptions]? = nil,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        concurrentQueue.async(flags: .barrier) { [weak self] in
            self?.decoratee.write(payload: payload, to: fileURL, options: options, completion: completion)
        }
    }

    // READS should be synchronous
    func contentsOfFileAt<T: Decodable>(url: URL, completion: ((Result<T, Error>) -> Void)?) -> T? {
        concurrentQueue.sync { [weak self] in
            self?.decoratee.contentsOfFileAt(url: url, completion: completion)
        }
    }

    func getFileUrl(fileName: String) -> URL? {
        decoratee.getFileUrl(fileName: fileName)
    }

    func isFileExistent(fileName: String) -> Bool {
        decoratee.isFileExistent(fileName: fileName)
    }

    // DELETE should be asynchronous and use a `barrier`
    func deleteFileAtUrl(at URL: URL, completion: ((Result<Void, Error>) -> Void)?) {
        concurrentQueue.async(flags: .barrier) { [weak self] in
            self?.decoratee.deleteFileAtUrl(at: URL, completion: completion)
        }
    }

    /// Runs `work` as one asynchronous barrier: exclusive of every read, write and delete on this queue, and ordered
    /// with the other barriers in submission order. `work` is handed the underlying store, whose operations are
    /// synchronous, so several of them — a directory scan, deletes, a write — land as a single step, and the caller
    /// returns as soon as the barrier is queued.
    func performExclusively(_ work: @escaping (FileStorage) -> Void) {
        concurrentQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            work(self.decoratee)
        }
    }

    /// Performs an atomic read-modify-write operation using a barrier.
    /// The entire operation (read, transform, write) happens within a single barrier block,
    /// preventing race conditions between concurrent saves.
    func atomicReadModifyWrite<T: Codable>(
        url: URL,
        defaultValue: T,
        transform: @escaping (T) -> T,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        concurrentQueue.async(flags: .barrier) { [weak self] in
            guard let self else {
                completion?(.failure(RoktError("FileStorage deallocated")))
                return
            }

            // Read current value (or use default if file doesn't exist)
            let currentValue: T = self.decoratee.contentsOfFileAt(url: url, completion: nil) ?? defaultValue

            // Transform
            let newValue = transform(currentValue)

            // Write back
            self.decoratee.write(
                payload: newValue,
                to: url,
                options: [.createIntermediateDirectories],
                completion: completion
            )
        }
    }
}

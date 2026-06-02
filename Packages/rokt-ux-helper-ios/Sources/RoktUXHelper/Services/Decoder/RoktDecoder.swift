import Foundation

@available(iOS 13, *)
struct RoktDecoder {

    func decode<T: Decodable>(_ type: T.Type, _ string: String) throws -> T {
        guard let data = string.data(using: .utf8) else {
            throw RoktUXError.experienceResponseMapping
        }

        var result: Result<T, Error>?
        let semaphore = DispatchSemaphore(value: 0)

        // Decode on a dedicated thread with an expanded stack so deeply nested but otherwise
        // schema-compatible payloads remain safe to parse.
        let decodingThread = Thread {
            defer { semaphore.signal() }
            do {
                let decoded = try JSONDecoder().decode(type, from: data)
                result = .success(decoded)
            } catch {
                result = .failure(error)
            }
        }
        decodingThread.name = "com.rokt.decoder"
        decodingThread.stackSize = max(decodingThread.stackSize, 8 * 1024 * 1024)
        decodingThread.qualityOfService = Thread.current.qualityOfService
        decodingThread.start()

        semaphore.wait()

        return try result
            .unwrap(orThrow: RoktUXError.experienceResponseMapping)
            .get()
    }
}

import Foundation

/// A protocol that defines the methods for a file storage system
protocol FileStorage: AnyObject {
    func write<T: Encodable>(payload: T,
                             to fileURL: URL,
                             options: [RoktDownloadOptions]?,
                             completion: ((Result<Void, Error>) -> Void)?)
    func contentsOfFileAt<T: Decodable>(url: URL, completion: ((Result<T, Error>) -> Void)?) -> T?
    func getFileUrl(fileName: String) -> URL?
    func isFileExistent(fileName: String) -> Bool

    /// Removes the storage file at the provided URL
    ///
    /// - Parameters:
    ///   - URL: The URL of the file to remove
    ///   - completion: A completion handler that returns a result of type `Void` or an error
    func deleteFileAtUrl(at URL: URL, completion: ((Result<Void, Error>) -> Void)?)
}

class JSONBackingStore: FileStorage {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func write<T: Encodable>(payload: T,
                             to fileURL: URL,
                             options: [RoktDownloadOptions]? = nil,
                             completion: ((Result<Void, Error>) -> Void)?) {
        do {
            let encodedData = try JSONEncoder().encode(payload)

            if let options,
               options.contains(.createIntermediateDirectories) {
                let directory = fileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            try encodedData.write(to: fileURL)
            completion?(.success(()))
        } catch {
            completion?(.failure(error))
        }
    }

    func contentsOfFileAt<T: Decodable>(url: URL, completion: ((Result<T, Error>) -> Void)?) -> T? {
        do {
            guard fileManager.fileExists(atPath: url.path) else {
                completion?(.failure(RoktError("File does not exist")))
                return nil
            }

            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let decodedData = try JSONDecoder().decode(T.self, from: data)

            completion?(.success(decodedData))

            return decodedData
        } catch {
            completion?(.failure(error))

            return nil
        }
    }

    func getFileUrl(fileName: String) -> URL? {
        guard let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            return nil
        }
        return documentsUrl.appendingPathComponent(fileName).appendingPathExtension("json")
    }

    func isFileExistent(fileName: String) -> Bool {
        guard let fileURL = getFileUrl(fileName: fileName) else { return false }
        return fileManager.fileExists(atPath: fileURL.path)
    }

    func deleteFileAtUrl(at URL: URL, completion: ((Result<Void, Error>) -> Void)?) {
        do {
            try fileManager.removeItem(at: URL)
            completion?(.success(()))
        } catch let error as NSError {
            if isFailedToRemove(error: error),
               let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError,
               isDoesNotExist(error: underlying) {
                completion?(.success(()))
            } else {
                // a different error which should be handled
                completion?(.failure(error))
            }
        }

        func isDoesNotExist(error: NSError) -> Bool {
            return error.domain == NSPOSIXErrorDomain && error.code == ENOENT
        }

        func isFailedToRemove(error: NSError) -> Bool {
            return error.domain == NSCocoaErrorDomain && error.code == 4
        }
    }
}

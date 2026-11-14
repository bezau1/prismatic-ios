import Foundation

/// async URLSession wrappers (the built-in async APIs need iOS 15; we target iOS 14).
extension URLSession {
    func pData(from url: URL) async throws -> (Data, URLResponse) { try await pData(for: URLRequest(url: url)) }
    func pData(for req: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { c in
            dataTask(with: req) { d, r, e in
                if let e = e { c.resume(throwing: e) } else { c.resume(returning: (d ?? Data(), r!)) }
            }.resume()
        }
    }
    func pDownload(from url: URL) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { c in
            downloadTask(with: url) { tmp, r, e in
                if let e = e { return c.resume(throwing: e) }
                // the temp file is deleted when this block returns: move it first
                let keep = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                do { try FileManager.default.moveItem(at: tmp!, to: keep); c.resume(returning: (keep, r!)) }
                catch { c.resume(throwing: error) }
            }.resume()
        }
    }
}

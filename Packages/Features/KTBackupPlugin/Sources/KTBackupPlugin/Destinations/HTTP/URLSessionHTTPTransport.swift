import Foundation

public struct URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: HTTPRequestSpec, body: HTTPBody, progress: BackupProgressHandler?) async throws -> HTTPResponse {
        let urlRequest = makeRequest(request)
        let delegate = progress.map(TransferProgressDelegate.init)
        let (data, response): (Data, URLResponse)
        switch body {
        case .empty:
            (data, response) = try await session.data(for: urlRequest, delegate: delegate)
        case let .data(payload):
            (data, response) = try await session.upload(for: urlRequest, from: payload, delegate: delegate)
        case let .file(url):
            (data, response) = try await session.upload(for: urlRequest, fromFile: url, delegate: delegate)
        }
        return try wrap(response, body: data)
    }

    public func download(_ request: HTTPRequestSpec, to fileURL: URL, progress: BackupProgressHandler?) async throws -> HTTPResponse {
        let delegate = progress.map(TransferProgressDelegate.init)
        let (temporary, response) = try await session.download(for: makeRequest(request), delegate: delegate)
        let wrapped = try wrap(response, body: Data())
        guard wrapped.isSuccess else {
            let body = (try? Data(contentsOf: temporary)) ?? Data()
            try? FileManager.default.removeItem(at: temporary)
            return HTTPResponse(status: wrapped.status, headers: wrapped.headers, body: body)
        }
        try? FileManager.default.removeItem(at: fileURL)
        try FileManager.default.moveItem(at: temporary, to: fileURL)
        return wrapped
    }

    private func makeRequest(_ spec: HTTPRequestSpec) -> URLRequest {
        var request = URLRequest(url: spec.url, timeoutInterval: 120)
        request.httpMethod = spec.method
        for (name, value) in spec.headers where name.lowercased() != "host" {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }

    private func wrap(_ response: URLResponse, body: Data) throws -> HTTPResponse {
        guard let http = response as? HTTPURLResponse else {
            throw BackupDestinationError.remote("The server returned an invalid response.")
        }
        let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            result[String(describing: pair.key)] = String(describing: pair.value)
        }
        return HTTPResponse(status: http.statusCode, headers: headers, body: body)
    }
}

private final class TransferProgressDelegate: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate {
    private let handler: BackupProgressHandler

    init(_ handler: @escaping BackupProgressHandler) {
        self.handler = handler
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        handler(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        handler(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}

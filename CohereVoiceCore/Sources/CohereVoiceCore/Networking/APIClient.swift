import Foundation

public actor APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let keyProvider: any APIKeyProviding

    public init(
        keyProvider: any APIKeyProviding,
        baseURL: URL = URL(string: CohereModels.baseURL)!,
        session: URLSession? = nil
    ) {
        self.keyProvider = keyProvider
        self.baseURL = baseURL
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 90
            self.session = URLSession(configuration: config)
        }
    }

    public func send(_ request: APIRequest) async throws -> Data {
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                return try await perform(request)
            } catch let error as APIError {
                if attempt == 0 {
                    switch error {
                    case .timeout:
                        lastError = error
                        try await Task.sleep(for: .milliseconds(300))
                        continue
                    case .status(let code) where (500...599).contains(code):
                        lastError = error
                        try await Task.sleep(for: .milliseconds(300))
                        continue
                    default:
                        throw error
                    }
                }
                throw error
            }
        }
        throw lastError ?? APIError.unknown
    }

    private func perform(_ request: APIRequest) async throws -> Data {
        guard let url = URL(string: request.path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeout
        let key = try await keyProvider.apiKey()
        urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("cohere-voice/1.0", forHTTPHeaderField: "User-Agent")
        for (header, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: header)
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.unknown
            }
            switch http.statusCode {
            case 200...299:
                return data
            case 401:
                throw APIError.authenticationFailed
            case 429:
                throw APIError.rateLimited
            default:
                throw APIError.status(http.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw APIError.noNetwork
            case .timedOut:
                throw APIError.timeout
            default:
                throw APIError.unknown
            }
        } catch is CancellationError {
            throw DictationError.cancelled
        }
    }
}

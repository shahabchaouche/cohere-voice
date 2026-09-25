import Foundation

public enum APIError: Error, Sendable, Equatable {
    case invalidURL
    case authenticationFailed
    case rateLimited
    case timeout
    case noNetwork
    case status(Int)
    case unknown

    func asDictationError(for stage: APIRequestStage) -> DictationError {
        switch self {
        case .authenticationFailed: .authenticationFailed
        case .rateLimited: .rateLimited
        case .timeout: .timeout
        case .noNetwork: .noNetwork
        case .status(let code): stage.failure(statusCode: code)
        case .invalidURL, .unknown: stage.failure(statusCode: nil)
        }
    }
}

enum APIRequestStage {
    case transcription
    case rewrite

    func failure(statusCode: Int?) -> DictationError {
        switch self {
        case .transcription: .transcriptionFailed(statusCode)
        case .rewrite: .rewriteFailed(statusCode)
        }
    }
}

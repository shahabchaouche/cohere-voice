import Foundation

public struct APIRequest: Sendable {
    public var method: String
    public var path: String
    public var headers: [String: String]
    public var body: Data
    public var timeout: TimeInterval

    public init(
        method: String = "POST",
        path: String,
        headers: [String: String] = [:],
        body: Data,
        timeout: TimeInterval = 60
    ) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

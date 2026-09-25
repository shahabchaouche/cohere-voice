import Foundation

public struct MultipartForm: Sendable {
    public let boundary: String
    private var parts: [Part] = []

    public init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    public mutating func addField(name: String, value: String) {
        parts.append(.field(name: name, value: value))
    }

    public mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        parts.append(.file(name: name, filename: filename, mimeType: mimeType, data: data))
    }

    public var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    public func encode() -> Data {
        var body = Data()
        for part in parts {
            body.append(ascii("--\(boundary)\r\n"))
            switch part {
            case .field(let name, let value):
                body.append(ascii("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"))
                body.append(ascii(value))
                body.append(ascii("\r\n"))
            case .file(let name, let filename, let mimeType, let data):
                body.append(ascii("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"))
                body.append(ascii("Content-Type: \(mimeType)\r\n\r\n"))
                body.append(data)
                body.append(ascii("\r\n"))
            }
        }
        body.append(ascii("--\(boundary)--\r\n"))
        return body
    }

    private enum Part: Sendable {
        case field(name: String, value: String)
        case file(name: String, filename: String, mimeType: String, data: Data)
    }

    private func ascii(_ string: String) -> Data {
        Data(string.utf8)
    }
}

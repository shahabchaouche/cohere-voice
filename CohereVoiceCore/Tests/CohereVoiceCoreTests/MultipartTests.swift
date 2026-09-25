import Foundation
import Testing
@testable import CohereVoiceCore

struct MultipartTests {
    @Test func goldenBody() {
        var form = MultipartForm(boundary: "Boundary-TEST")
        form.addField(name: "model", value: CohereModels.transcribe)
        form.addField(name: "language", value: "en")
        form.addFile(name: "file", filename: "audio.wav", mimeType: "audio/wav", data: Data([0x01, 0x02]))
        let body = String(decoding: form.encode(), as: UTF8.self)
        let expected = """
        --Boundary-TEST\r
        Content-Disposition: form-data; name="model"\r
        \r
        \(CohereModels.transcribe)\r
        --Boundary-TEST\r
        Content-Disposition: form-data; name="language"\r
        \r
        en\r
        --Boundary-TEST\r
        Content-Disposition: form-data; name="file"; filename="audio.wav"\r
        Content-Type: audio/wav\r
        \r
        \u{01}\u{02}\r
        --Boundary-TEST--\r

        """
        #expect(body == expected)
        #expect(form.contentType == "multipart/form-data; boundary=Boundary-TEST")
    }
}

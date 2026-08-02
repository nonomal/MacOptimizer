import Foundation

private enum VerificationError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message): return message
        }
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw VerificationError.failed("Missing mock handler") }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            fputs("Mock request failed: \(error)\n", stderr)
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@main
enum AIProviderClientVerifier {
    static func main() async {
        do {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockURLProtocol.self]
            let client = AIProviderClient(session: URLSession(configuration: configuration))

            try await verifyOpenAI(client)
            try await verifyGemini(client)
            try await verifyClaude(client)
            print("AI provider verification passed (OpenAI, Gemini, Claude).")
        } catch {
            fputs("AI provider verification failed: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func verifyOpenAI(_ client: AIProviderClient) async throws {
        MockURLProtocol.handler = { request in
            try require(request.url?.path == "/v1/chat/completions", "OpenAI endpoint path mismatch")
            try require(request.value(forHTTPHeaderField: "Authorization") == "Bearer openai-secret", "OpenAI authorization header mismatch")
            let body = try jsonBody(request)
            try require(body["model"] as? String == "openai-test", "OpenAI model mismatch")
            let messages = body["messages"] as? [[String: Any]]
            let content = messages?.last?["content"] as? [[String: Any]]
            let imageURL = (content?.last?["image_url"] as? [String: Any])?["url"] as? String
            try require(imageURL == "data:image/png;base64,AQID", "OpenAI image data URL mismatch")
            let response = try response(for: request)
            let data = try JSONSerialization.data(withJSONObject: [
                "choices": [["message": ["content": [["type": "text", "text": "{\"status\":\"ok\"}"]]]]]
            ])
            return (response, data)
        }

        let result = try await client.generateJSON(
            configuration: .init(provider: .openAI, baseURL: "https://example.test/v1", apiKey: "openai-secret", model: "openai-test"),
            systemPrompt: "system",
            userPrompt: "user",
            attachments: [.init(data: Data([1, 2, 3]), mimeType: "image/png")]
        )
        try require(result.contains("ok"), "OpenAI response parsing failed")
    }

    private static func verifyGemini(_ client: AIProviderClient) async throws {
        MockURLProtocol.handler = { request in
            try require(request.url?.path == "/v1beta/models/gemini-test:generateContent", "Gemini endpoint path mismatch")
            let components = URLComponents(url: try requiredURL(request), resolvingAgainstBaseURL: false)
            try require(components?.queryItems?.first(where: { $0.name == "key" })?.value == "gemini-secret", "Gemini API key query mismatch")
            let body = try jsonBody(request)
            try require(body["contents"] != nil, "Gemini contents payload missing")
            let contents = body["contents"] as? [[String: Any]]
            let parts = contents?.first?["parts"] as? [[String: Any]]
            let inlineData = parts?.last?["inlineData"] as? [String: Any]
            try require(inlineData?["mimeType"] as? String == "image/jpeg", "Gemini image MIME type mismatch")
            try require(inlineData?["data"] as? String == "AQID", "Gemini inline image mismatch")
            let response = try response(for: request)
            let data = try JSONSerialization.data(withJSONObject: [
                "candidates": [["content": ["parts": [["text": "{\"status\":\"ok\"}"]]]]]
            ])
            return (response, data)
        }

        let result = try await client.generateJSON(
            configuration: .init(provider: .gemini, baseURL: "https://example.test/v1beta", apiKey: "gemini-secret", model: "gemini-test"),
            systemPrompt: "system",
            userPrompt: "user",
            attachments: [.init(data: Data([1, 2, 3]), mimeType: "image/jpeg")]
        )
        try require(result.contains("ok"), "Gemini response parsing failed")
    }

    private static func verifyClaude(_ client: AIProviderClient) async throws {
        MockURLProtocol.handler = { request in
            try require(request.url?.path == "/v1/messages", "Claude endpoint path mismatch")
            try require(request.value(forHTTPHeaderField: "x-api-key") == "claude-secret", "Claude API key header mismatch")
            try require(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01", "Claude version header mismatch")
            let body = try jsonBody(request)
            try require(body["model"] as? String == "claude-test", "Claude model mismatch")
            let messages = body["messages"] as? [[String: Any]]
            let content = messages?.first?["content"] as? [[String: Any]]
            let source = content?.last?["source"] as? [String: Any]
            try require(source?["media_type"] as? String == "image/webp", "Claude image MIME type mismatch")
            try require(source?["data"] as? String == "AQID", "Claude base64 image mismatch")
            let response = try response(for: request)
            let data = try JSONSerialization.data(withJSONObject: [
                "content": [["type": "text", "text": "{\"status\":\"ok\"}"]]
            ])
            return (response, data)
        }

        let result = try await client.generateJSON(
            configuration: .init(provider: .claude, baseURL: "https://example.test/v1", apiKey: "claude-secret", model: "claude-test"),
            systemPrompt: "system",
            userPrompt: "user",
            attachments: [.init(data: Data([1, 2, 3]), mimeType: "image/webp")]
        )
        try require(result.contains("ok"), "Claude response parsing failed")
    }

    private static func jsonBody(_ request: URLRequest) throws -> [String: Any] {
        let data: Data
        if let body = request.httpBody {
            data = body
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var collected = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let count = stream.read(buffer, maxLength: 4096)
                if count < 0 { throw stream.streamError ?? VerificationError.failed("Could not read request body stream") }
                if count == 0 { break }
                collected.append(buffer, count: count)
            }
            data = collected
        } else {
            throw VerificationError.failed("Request body missing")
        }
        guard
              let body = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VerificationError.failed("Invalid JSON request body")
        }
        return body
    }

    private static func requiredURL(_ request: URLRequest) throws -> URL {
        guard let url = request.url else { throw VerificationError.failed("Request URL missing") }
        return url
    }

    private static func response(for request: URLRequest) throws -> HTTPURLResponse {
        guard let response = HTTPURLResponse(url: try requiredURL(request), statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else {
            throw VerificationError.failed("Could not create mock response")
        }
        return response
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw VerificationError.failed(message) }
    }
}

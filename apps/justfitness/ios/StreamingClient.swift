import Foundation

struct LLMRequest: Encodable {
    let context: String
}

final class LLMStreamingClient {
    private let endpoint: URL

    init(endpoint: URL) {
        self.endpoint = endpoint
    }

    func streamSuggestion(
        context: String,
        onDelta: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = LLMRequest(context: context)
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            await MainActor.run { onError(error) }
            return
        }

        do {
            let (bytes, _) = try await URLSession.shared.bytes(for: request)
            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let dataString = String(line.dropFirst(6))
                if dataString == "[DONE]" {
                    await MainActor.run { onComplete() }
                    return
                }

                guard let data = dataString.data(using: .utf8) else { continue }
                if let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = event["type"] as? String {
                    if type == "response.output_text.delta",
                       let delta = event["delta"] as? String {
                        await MainActor.run { onDelta(delta) }
                    } else if type == "response.completed" {
                        await MainActor.run { onComplete() }
                        return
                    }
                }
            }
        } catch {
            await MainActor.run { onError(error) }
        }
    }
}

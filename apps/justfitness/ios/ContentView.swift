import SwiftUI

struct ContentView: View {
    @State private var isStreaming = false
    @State private var outputText = ""
    @State private var errorText: String?

    private let client = LLMStreamingClient(
        endpoint: URL(string: "https://YOUR-WORKER-DOMAIN/ai/suggest")!
    )

    var body: some View {
        VStack(spacing: 16) {
            Text("Trainer Assistant (Stream)")
                .font(.headline)

            ScrollView {
                Text(outputText.isEmpty ? "Waiting for stream..." : outputText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }

            if let errorText {
                Text(errorText)
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            Button(action: startStreaming) {
                Text(isStreaming ? "Streaming..." : "Start Stream")
                    .frame(maxWidth: .infinity)
            }
            .disabled(isStreaming)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func startStreaming() {
        isStreaming = true
        errorText = nil
        outputText = ""

        let sampleContext = """
        Exercise: Bench Press
        Today Sets: 75kg x 8, 75kg x 7
        Last Session: 72.5kg x 8, 72.5kg x 8
        Goal: Strength
        """

        Task {
            await client.streamSuggestion(
                context: sampleContext,
                onDelta: { delta in
                    outputText += delta
                },
                onComplete: {
                    isStreaming = false
                },
                onError: { error in
                    isStreaming = false
                    errorText = error.localizedDescription
                }
            )
        }
    }
}

#Preview {
    ContentView()
}

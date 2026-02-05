# Handoff: AI Fitness Assistant

**Handoff** is a premium fitness application that acts as your intelligent workout partner. It uses AI to provide real-time suggestions for your next set, helping you optimize your training progression without the friction of manual calculation.

## 📂 Repository Structure

This is a monorepo containing the main iOS application and the AI backend prototype.

| Path | Description | Stack |
| :--- | :--- | :--- |
| **`apps/handoff-ios`** | **Main iOS Application**<br>The production-ready fitness tracker with a premium "Cyber Fitness" UI. | SwiftUI, SwiftData, Combine |
| **`apps/justfitness`** | **AI Backend Prototype**<br>Proof-of-concept for the AI suggestion engine using Cloudflare Workers and OpenAI. | Cloudflare Workers, TypeScript, OpenAI API |

---

## 🚀 Features

### Handoff iOS App
-   **Premium UI**: A "Cyber/Pro" aesthetic with dark settings and neon accents.
-   **Smart Logging**: Frictionless set logging with swipe gestures for weight/rep adjustments.
-   **Visual Timers**: Intuitive visual progress bars for rest intervals.
-   **Set History**: Immediate context on your previous sets and performance.
-   **AI Insight Card**: (In Progress) Dedicated UI for receiving intelligent next-set recommendations.

### AI Engine (Prototype)
-   **Streaming AI**: Server-Sent Events (SSE) for low-latency, real-time text generation.
-   **Context Aware**: Analyzes recent performance to suggest optimal weight and reps.
-   **Privacy Focused**: OpenAI API keys are secured server-side on Cloudflare Workers.

---

## 🛠️ Getting Started

### 1. iOS Application
1.  Open `apps/handoff-ios/Handoff.xcodeproj` in Xcode 15+.
2.  Ensure your target is set to an iOS 17.0+ Simulator or Device.
3.  Build and Run (`Cmd + R`).

### 2. AI Worker (Development)
To run the backend prototype locally:

```bash
cd apps/justfitness/worker
npm install
npx wrangler dev
```

*Note: You will need an `OPENAI_API_KEY` set in your wrangler secrets or environment.*

---

## 🔮 Roadmap

-   [ ] **Integration**: Connect the `handoff-ios` app to the `justfitness` worker for live AI suggestions.
-   [ ] **Personalization**: User-specific routine generation.
-   [ ] **Analytics**: Long-term progression charts and volume visualization.
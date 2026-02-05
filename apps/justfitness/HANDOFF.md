# Handoff: iOS Trainer Assistant (SwiftUI + OpenAI + Cloudflare Workers)

## TL;DR
We chose **SwiftUI**, **OpenAI**, and **Cloudflare Workers** with **streaming**.  
Test model is **`gpt-4o-mini`** (cheapest).  
Worker proxies OpenAI `Responses API` via SSE passthrough.  
iOS streams SSE and renders deltas live.

---

## Goals (Product)
- Reduce logging friction to near-zero.
- One-tap set completion + swipe/long-press adjustments.
- AI is a **scribe**: auto-fill, progression, anomaly check, summary.
- “3-second logging” target.

---

## Key Decisions
- **Serverless:** Cloudflare Workers (global edge, low-latency).
- **LLM:** OpenAI `Responses API` with `stream: true`.
- **Test model:** `gpt-4o-mini` (lowest cost).
- **Output format:** line-based for streaming-friendly parsing.

---

## Architecture
iOS (SwiftUI)
→ Cloudflare Worker (`/ai/suggest`)
→ OpenAI `v1/responses` (SSE stream)
→ iOS parses `response.output_text.delta` events and updates UI in real time.

Reason: API key safety (key stays server-side).

---

## Files Created

### Cloudflare Worker
- `worker/wrangler.toml`
  - `OPENAI_MODEL` default set to `gpt-4o-mini`.
- `worker/package.json`
- `worker/tsconfig.json`
- `worker/src/index.ts`
  - POST `/ai/suggest`
  - Accepts `{ "context": "..." }`
  - Streams SSE passthrough from OpenAI.
  - CORS enabled.

### iOS (SwiftUI Sample)
- `ios/StreamingClient.swift`
  - Streams SSE via `URLSession.bytes(for:)`.
  - Handles `response.output_text.delta` + `response.completed`.
- `ios/ContentView.swift`
  - Demo UI for streaming.
  - Replace `https://YOUR-WORKER-DOMAIN/ai/suggest` with deployed worker URL.

---

## API Contract

**Request**
```
POST /ai/suggest
Content-Type: application/json

{
  "context": "Exercise: Bench Press\nToday Sets: 75kg x 8, 75kg x 7\nLast Session: 72.5kg x 8, 72.5kg x 8\nGoal: Strength"
}
```

**Streamed Output (line-based)**
```
NEXT_SET: 80kg x 8
PROGRESSION: 다음 세트 82.5kg 시도
ANOMALY: 직전 대비 반복수 급감
SUMMARY1: 오늘 총 볼륨 12% 증가
SUMMARY2: 벤치 PR 근접
SUMMARY3: 다음은 80kg 3세트 유지
```

---

## How To Run (Worker)
```
cd worker
npm install
npx wrangler dev
```

Set secret:
```
npx wrangler secret put OPENAI_API_KEY
```

Optional (per env):
```
OPENAI_MODEL=gpt-4o-mini
```

---

## Next Steps (Recommended)
1. Replace demo `ContentView` with real workout flow UI.
2. Parse line-based output into structured cards (next set, progression, anomaly, summary).
3. Add server-side input validation and rate limiting.
4. Lock CORS to app domain in production.
5. Add request context schema (recent sets, routine template, session stats).
6. Persist LLM outputs to session history.

---

## Open Questions
- Should output be strict JSON for long-term reliability?
- Which field order should be canonical for parsing?
- Should anomalies override progression suggestion?


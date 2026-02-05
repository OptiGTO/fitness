export interface Env {
  OPENAI_API_KEY: string;
  OPENAI_MODEL?: string;
}

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

const SYSTEM_PROMPT = [
  "You are a concise fitness logging assistant.",
  "You are a scribe, not a coach.",
  "Output must be short, factual, and structured.",
  "Do not ask questions.",
  "Always follow the output format.",
].join(" ");

const OUTPUT_FORMAT = [
  "NEXT_SET: <weight> x <reps> (optional RPE)",
  "PROGRESSION: <one short line>",
  "ANOMALY: <one short line or 'none'>",
  "SUMMARY1: <short line>",
  "SUMMARY2: <short line>",
  "SUMMARY3: <short line>",
].join("\n");

function jsonError(status: number, message: string) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json",
    },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (url.pathname !== "/ai/suggest") {
      return new Response("Not Found", { status: 404, headers: CORS_HEADERS });
    }

    if (request.method !== "POST") {
      return new Response("Method Not Allowed", {
        status: 405,
        headers: CORS_HEADERS,
      });
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return jsonError(400, "Invalid JSON body.");
    }

    if (!body || typeof body !== "object") {
      return jsonError(400, "Invalid request payload.");
    }

    const context = (body as { context?: unknown }).context;
    if (typeof context !== "string" || context.trim().length === 0) {
      return jsonError(400, "Missing required field: context (string).");
    }

    const model = env.OPENAI_MODEL || "gpt-4o-mini";

    const openAiBody = {
      model,
      stream: true,
      temperature: 0.3,
      input: [
        {
          role: "system",
          content: [{ type: "input_text", text: SYSTEM_PROMPT }],
        },
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: `Context:\n${context}\n\nOutput format:\n${OUTPUT_FORMAT}`,
            },
          ],
        },
      ],
    };

    const upstream = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(openAiBody),
    });

    if (!upstream.ok || !upstream.body) {
      const errorText = await upstream.text();
      return new Response(errorText, {
        status: upstream.status,
        headers: {
          ...CORS_HEADERS,
          "Content-Type": upstream.headers.get("Content-Type") || "text/plain",
        },
      });
    }

    const headers = new Headers(CORS_HEADERS);
    headers.set("Content-Type", "text/event-stream");
    headers.set("Cache-Control", "no-cache");
    headers.set("Connection", "keep-alive");

    return new Response(upstream.body, {
      status: upstream.status,
      headers,
    });
  },
};

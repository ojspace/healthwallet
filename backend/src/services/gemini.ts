import { config } from "../config.js";

/**
 * Call AI via OpenRouter (OpenAI-compatible API).
 * Falls back to Google Gemini if OpenRouter key is not set.
 */
export async function callGemini(
  systemPrompt: string,
  messages: { role: "user" | "assistant"; content: string }[],
): Promise<string> {
  // Primary: OpenRouter with Grok3 Fast
  if (config.openrouterApiKey) {
    return callOpenRouter(systemPrompt, messages);
  }

  // Fallback: Google Gemini
  if (config.googleApiKey) {
    return callGeminiDirect(systemPrompt, messages);
  }

  return "AI features require an API key. Please configure OPENROUTER_API_KEY or GOOGLE_API_KEY.";
}

async function callOpenRouter(
  systemPrompt: string,
  messages: { role: "user" | "assistant"; content: string }[],
): Promise<string> {
  const openaiMessages = [
    { role: "system" as const, content: systemPrompt },
    ...messages.map((m) => ({
      role: m.role as "user" | "assistant",
      content: m.content,
    })),
  ];

  const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${config.openrouterApiKey}`,
      "Content-Type": "application/json",
      "HTTP-Referer": config.baseUrl,
      "X-Title": "HealthWallet",
    },
    body: JSON.stringify({
      model: config.openrouterModel,
      messages: openaiMessages,
      temperature: 0.7,
      max_tokens: 300,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error("[OpenRouter] API error:", response.status, errorText);
    return "I'm having trouble connecting right now. Please try again in a moment.";
  }

  const data = await response.json() as any;
  const text = data.choices?.[0]?.message?.content;

  if (!text) {
    return "I wasn't able to generate a response. Could you rephrase your question?";
  }

  return text;
}

// Legacy Gemini support
interface GeminiMessage {
  role: "user" | "model";
  parts: { text: string }[];
}

interface GeminiResponse {
  candidates?: { content?: { parts?: { text?: string }[] } }[];
}

async function callGeminiDirect(
  systemPrompt: string,
  messages: { role: "user" | "assistant"; content: string }[],
): Promise<string> {
  const geminiMessages: GeminiMessage[] = messages.map((m) => ({
    role: m.role === "assistant" ? "model" : "user",
    parts: [{ text: m.content }],
  }));

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${config.googleApiKey}`;

  const body = {
    system_instruction: { parts: [{ text: systemPrompt }] },
    contents: geminiMessages,
    generationConfig: {
      temperature: 0.7,
      topP: 0.9,
      maxOutputTokens: 300,
    },
    safetySettings: [
      { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_ONLY_HIGH" },
      { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_ONLY_HIGH" },
      { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_ONLY_HIGH" },
      { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_ONLY_HIGH" },
    ],
  };

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error("[Gemini] API error:", response.status, errorText);
    return "I'm having trouble connecting right now. Please try again in a moment.";
  }

  const data = (await response.json()) as GeminiResponse;
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

  if (!text) {
    return "I wasn't able to generate a response. Could you rephrase your question?";
  }

  return text;
}

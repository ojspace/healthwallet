import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { ObjectId } from "mongodb";
import { getDb } from "../db.js";
import { getCurrentUser } from "../middleware/auth.js";
import { sendMessageSchema } from "../schemas/chat.js";
import { buildChatContext } from "../services/chat-context.js";
import { callGemini } from "../services/gemini.js";

const chat = new Hono();

interface ChatMessage {
  _id: ObjectId;
  user_id: string;
  role: "user" | "assistant";
  content: string;
  created_at: Date;
}

// POST /chat — send a message and get AI response
chat.post("/", async (c) => {
  const user = await getCurrentUser(c);
  const body = await c.req.json();
  const parsed = sendMessageSchema.safeParse(body);

  if (!parsed.success) {
    throw new HTTPException(400, { message: "Invalid request body" });
  }

  const db = getDb();
  const userId = user._id.toString();
  const collection = db.collection<ChatMessage>("chat_messages");

  // Save user message
  const userMsg: Omit<ChatMessage, "_id"> = {
    user_id: userId,
    role: "user",
    content: parsed.data.message,
    created_at: new Date(),
  };
  await collection.insertOne(userMsg as ChatMessage);

  // Fetch recent conversation history (last 20 messages for context)
  const recentMessages = await collection
    .find({ user_id: userId })
    .sort({ created_at: -1 })
    .limit(20)
    .toArray();

  // Reverse to get chronological order
  recentMessages.reverse();

  // Build RAG context
  const { systemPrompt } = await buildChatContext(user);

  // Call Gemini with context + history
  const conversationHistory = recentMessages.map((m) => ({
    role: m.role as "user" | "assistant",
    content: m.content,
  }));

  const aiResponse = await callGemini(systemPrompt, conversationHistory);

  // Save AI response
  const assistantMsg: Omit<ChatMessage, "_id"> = {
    user_id: userId,
    role: "assistant",
    content: aiResponse,
    created_at: new Date(),
  };
  const result = await collection.insertOne(assistantMsg as ChatMessage);

  return c.json({
    id: result.insertedId.toString(),
    role: "assistant",
    content: aiResponse,
    created_at: assistantMsg.created_at.toISOString(),
  });
});

// GET /chat/history — paginated chat history
chat.get("/history", async (c) => {
  const user = await getCurrentUser(c);
  const userId = user._id.toString();

  const limit = Math.min(parseInt(c.req.query("limit") ?? "50"), 100);
  const before = c.req.query("before");

  const db = getDb();
  const collection = db.collection<ChatMessage>("chat_messages");

  const filter: Record<string, any> = { user_id: userId };
  if (before) {
    try {
      filter._id = { $lt: new ObjectId(before) };
    } catch {
      throw new HTTPException(400, { message: "Invalid cursor" });
    }
  }

  const messages = await collection
    .find(filter)
    .sort({ created_at: -1 })
    .limit(limit + 1) // Fetch one extra to check if there are more
    .toArray();

  const hasMore = messages.length > limit;
  if (hasMore) messages.pop();

  // Return in chronological order
  messages.reverse();

  return c.json({
    messages: messages.map((m) => ({
      id: m._id.toString(),
      role: m.role,
      content: m.content,
      created_at: m.created_at.toISOString(),
    })),
    has_more: hasMore,
    cursor: hasMore && messages.length > 0 ? messages[0]._id.toString() : null,
  });
});

// GET /chat/suggestions — smart prompts based on user's data
chat.get("/suggestions", async (c) => {
  const user = await getCurrentUser(c);
  const db = getDb();
  const userId = user._id.toString();

  // Check what data the user has to generate relevant suggestions
  const [hasRecords, hasMetrics, hasLogs] = await Promise.all([
    db.collection("health_records").findOne({ user_id: user._id, status: "completed" }),
    db.collection("daily_metrics").findOne({ user_id: userId }),
    db.collection("quick_logs").findOne({ user_id: userId }),
  ]);

  const suggestions: { text: string; icon: string }[] = [];

  if (hasRecords) {
    suggestions.push(
      { text: "Explain my latest blood work", icon: "drop.fill" },
      { text: "What supplements should I take?", icon: "pills.fill" },
      { text: "What foods should I eat this week?", icon: "fork.knife" },
    );
  } else {
    suggestions.push(
      { text: "How do I get started?", icon: "questionmark.circle.fill" },
      { text: "What can you help me with?", icon: "sparkles" },
    );
  }

  if (hasMetrics) {
    suggestions.push(
      { text: "How's my sleep this week?", icon: "moon.fill" },
      { text: "Am I getting enough exercise?", icon: "figure.walk" },
    );
  }

  if (hasLogs) {
    suggestions.push(
      { text: "Why am I feeling tired?", icon: "battery.25" },
    );
  }

  // Always available
  suggestions.push(
    { text: "Give me a health tip for today", icon: "lightbulb.fill" },
  );

  // Return max 6
  return c.json({ suggestions: suggestions.slice(0, 6) });
});

export default chat;

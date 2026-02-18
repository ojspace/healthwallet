import { Hono } from "hono";
import { webhookCallback } from "grammy";
import { createBot } from "../services/telegram-bot.js";
import { encryptLinkPayload } from "../services/telegram-link.js";
import { startDigestScheduler } from "../services/daily-digest.js";
import { getCurrentUser } from "../middleware/auth.js";
import { getDb } from "../db.js";

const telegram = new Hono();

// Initialize bot (may be null if no token configured)
const bot = createBot();

// Start daily digest scheduler if bot is available
if (bot) {
  startDigestScheduler(bot);
}

// Webhook endpoint for Telegram updates
if (bot) {
  const handleUpdate = webhookCallback(bot, "std/http");

  telegram.post("/webhook", async (c) => {
    // Grammy's webhookCallback expects a raw Request and returns a Response.
    // Bridge from Hono context to the raw handler.
    const response = await handleUpdate(c.req.raw);
    return response;
  });
}

// GET /telegram/link -- generates a deep link for the authenticated user
telegram.get("/link", async (c) => {
  const user = await getCurrentUser(c);
  const userId = user._id.toString();

  const payload = await encryptLinkPayload(userId);
  const botUsername = "HealthWalletBot"; // TODO: make configurable
  const deepLink = `https://t.me/${botUsername}?start=${payload}`;

  return c.json({ link: deepLink, expires_in_seconds: 600 });
});

// DELETE /telegram/link -- unlinks telegram from the user's account
telegram.delete("/link", async (c) => {
  const user = await getCurrentUser(c);
  const db = getDb();

  await db.collection("users").updateOne(
    { _id: user._id },
    {
      $set: {
        telegram_id: null,
        telegram_linked_at: null,
        updated_at: new Date(),
      },
    },
  );

  return c.json({ status: "unlinked" });
});

export default telegram;

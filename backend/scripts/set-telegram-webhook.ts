/**
 * Register the Telegram webhook URL with the Telegram Bot API.
 *
 * Usage:
 *   bun run scripts/set-telegram-webhook.ts
 *
 * Requires TELEGRAM_BOT_TOKEN and BASE_URL environment variables.
 */
import { config } from "../src/config.js";

const BOT_TOKEN = config.telegramBotToken;
const WEBHOOK_URL = `${config.baseUrl}/api/v1/telegram/webhook`;

if (!BOT_TOKEN) {
  console.error("TELEGRAM_BOT_TOKEN is not set");
  process.exit(1);
}

const response = await fetch(
  `https://api.telegram.org/bot${BOT_TOKEN}/setWebhook`,
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      url: WEBHOOK_URL,
      allowed_updates: ["message", "callback_query"],
    }),
  },
);

const result = await response.json();
console.log("Webhook set result:", JSON.stringify(result, null, 2));
console.log(`Webhook URL: ${WEBHOOK_URL}`);

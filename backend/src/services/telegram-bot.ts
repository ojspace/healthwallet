import { Bot } from "grammy";
import { ObjectId } from "mongodb";
import { config } from "../config.js";
import { getDb } from "../db.js";
import { decryptLinkPayload } from "./telegram-link.js";
import type { User } from "../models/user.js";

/**
 * Create and configure the Grammy bot instance.
 * Returns null when no TELEGRAM_BOT_TOKEN is configured (e.g. local dev).
 */
export function createBot(): Bot | null {
  if (!config.telegramBotToken) {
    console.log("[Telegram] No bot token configured, skipping bot setup");
    return null;
  }

  const bot = new Bot(config.telegramBotToken);

  // ── /start ─────────────────────────────────────────────────────────
  // Handles both plain starts and deep-link account linking.
  bot.command("start", async (ctx) => {
    const payload = ctx.match; // Deep link payload from ?start=<payload>

    if (payload) {
      const userId = await decryptLinkPayload(payload);

      if (!userId) {
        await ctx.reply(
          "This link has expired. Please generate a new one from the HealthWallet app.",
        );
        return;
      }

      const db = getDb();
      const telegramId = ctx.from?.id;
      if (!telegramId) return;

      // Check if telegram is already linked to another account
      const existingLink = await db
        .collection<User>("users")
        .findOne({ telegram_id: telegramId });

      if (existingLink) {
        await ctx.reply(
          "Your Telegram is already linked to a HealthWallet account. Use /unlink first to switch accounts.",
        );
        return;
      }

      // Link telegram_id to user
      const result = await db.collection("users").updateOne(
        { _id: new ObjectId(userId) },
        {
          $set: {
            telegram_id: telegramId,
            telegram_linked_at: new Date(),
            updated_at: new Date(),
          },
        },
      );

      if (result.modifiedCount > 0) {
        await ctx.reply(
          "*HealthWallet Connected!*\n\n" +
            "You can now:\n" +
            "/today -- See your daily health summary\n" +
            "/log -- Quick mood & energy log\n" +
            "Send a food photo for nutrition analysis\n" +
            "Describe symptoms for AI correlation",
          { parse_mode: "Markdown" },
        );
      } else {
        await ctx.reply(
          "Could not link your account. Please try again from the app.",
        );
      }
    } else {
      await ctx.reply(
        "*Welcome to HealthWallet Bot!*\n\n" +
          "To get started, open the HealthWallet app and tap \"Link Telegram\" in your profile settings.\n\n" +
          "Once linked, you can:\n" +
          "/today -- Daily health summary\n" +
          "/log -- Quick mood & energy check-in\n" +
          "Send food photos for AI analysis\n" +
          "Describe how you feel for symptom tracking",
        { parse_mode: "Markdown" },
      );
    }
  });

  // ── /today ─────────────────────────────────────────────────────────
  bot.command("today", async (ctx) => {
    const user = await getLinkedUser(ctx.from?.id);
    if (!user) {
      await ctx.reply(
        "Please link your account first. Open HealthWallet app -> Profile -> Link Telegram.",
      );
      return;
    }

    const db = getDb();
    const userId = user._id.toString();
    const todayStr = new Date().toISOString().slice(0, 10);

    // Get today's HealthKit metric
    const metric = await db
      .collection("daily_metrics")
      .findOne({ user_id: userId, date: todayStr });

    // Calculate logging streak
    const logDates = await db
      .collection("quick_logs")
      .find({ user_id: userId }, { projection: { date: 1, _id: 0 } })
      .sort({ date: -1 })
      .limit(30)
      .toArray();

    const dateSet = new Set(logDates.map((l) => l.date as string));
    let streak = 0;
    const cursor = new Date();
    while (dateSet.has(cursor.toISOString().slice(0, 10))) {
      streak++;
      cursor.setDate(cursor.getDate() - 1);
    }

    // Build summary message
    const parts: string[] = ["*Today's Health Summary*\n"];

    if (metric) {
      if (typeof metric.steps === "number")
        parts.push(`Steps: ${metric.steps.toLocaleString()}`);
      if (typeof metric.sleep_hours === "number")
        parts.push(`Sleep: ${metric.sleep_hours.toFixed(1)}h`);
      if (typeof metric.resting_heart_rate === "number")
        parts.push(`Resting HR: ${metric.resting_heart_rate} bpm`);
      if (typeof metric.hrv_avg === "number")
        parts.push(`HRV: ${metric.hrv_avg.toFixed(0)} ms`);
    } else {
      parts.push("_No HealthKit data synced yet today._");
    }

    parts.push(`\nLogging streak: ${streak} days`);

    // Today's quick log
    const todayLog = await db
      .collection("quick_logs")
      .findOne({ user_id: userId, date: todayStr });

    if (todayLog) {
      const moods = ["Terrible", "Bad", "Okay", "Good", "Great"];
      parts.push(
        `\nMood: ${moods[(todayLog.mood as number) - 1] ?? "?"} | Energy: ${todayLog.energy}/5`,
      );
    } else {
      parts.push("\n_No mood log yet. Use /log to check in!_");
    }

    await ctx.reply(parts.join("\n"), { parse_mode: "Markdown" });
  });

  // ── /log ───────────────────────────────────────────────────────────
  bot.command("log", async (ctx) => {
    const user = await getLinkedUser(ctx.from?.id);
    if (!user) {
      await ctx.reply("Please link your account first.");
      return;
    }

    await ctx.reply(
      "How are you feeling? Pick a mood:\n\n" +
        "1 - Terrible\n" +
        "2 - Bad\n" +
        "3 - Okay\n" +
        "4 - Good\n" +
        "5 - Great\n\n" +
        "Reply with a number (1-5)",
    );
  });

  // ── /unlink ────────────────────────────────────────────────────────
  bot.command("unlink", async (ctx) => {
    const telegramId = ctx.from?.id;
    if (!telegramId) return;

    const db = getDb();
    const result = await db.collection("users").updateOne(
      { telegram_id: telegramId },
      {
        $set: {
          telegram_id: null,
          telegram_linked_at: null,
          updated_at: new Date(),
        },
      },
    );

    if (result.modifiedCount > 0) {
      await ctx.reply(
        "Your Telegram account has been unlinked from HealthWallet.",
      );
    } else {
      await ctx.reply("No linked account found.");
    }
  });

  // ── Text messages ──────────────────────────────────────────────────
  // Handles mood numbers (response to /log) and free-form text.
  bot.on("message:text", async (ctx) => {
    const text = ctx.message.text.trim();
    const user = await getLinkedUser(ctx.from?.id);
    if (!user) return; // Silently ignore unlinked users for non-command messages

    // Check if it's a mood number (1-5) -- likely response to /log
    const moodMatch = text.match(/^([1-5])$/);
    if (moodMatch) {
      const mood = parseInt(moodMatch[1], 10);
      const db = getDb();
      const userId = user._id.toString();
      const todayStr = new Date().toISOString().slice(0, 10);

      await db.collection("quick_logs").updateOne(
        { user_id: userId, date: todayStr },
        {
          $set: {
            mood,
            user_id: userId,
            date: todayStr,
            updated_at: new Date(),
            source: "telegram",
          },
          $setOnInsert: {
            energy: 3,
            symptoms: [],
            created_at: new Date(),
          },
        },
        { upsert: true },
      );

      const moods = ["Terrible", "Bad", "Okay", "Good", "Great"];
      await ctx.reply(
        `Mood logged: ${moods[mood - 1]}! Now rate your energy (1-5):`,
      );
      return;
    }

    // Default: acknowledge but defer AI analysis to a future release
    await ctx.reply(
      "Got it! Symptom analysis is coming in a future update.\n\n" +
        "For now, use /log for a quick check-in or /today for your daily summary.",
    );
  });

  // ── Photo messages ─────────────────────────────────────────────────
  // Placeholder for Vision AI food photo analysis.
  bot.on("message:photo", async (ctx) => {
    const user = await getLinkedUser(ctx.from?.id);
    if (!user) {
      await ctx.reply(
        "Please link your HealthWallet account first to analyze food photos.",
      );
      return;
    }

    await ctx.reply(
      "Food photo analysis coming soon! This feature is being developed.",
    );
  });

  return bot;
}

/** Find the HealthWallet user linked to a Telegram ID. */
async function getLinkedUser(
  telegramId: number | undefined,
): Promise<User | null> {
  if (!telegramId) return null;
  const db = getDb();
  return db
    .collection<User>("users")
    .findOne({ telegram_id: telegramId, is_active: true });
}

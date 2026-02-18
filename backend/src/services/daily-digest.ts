import { getDb } from "../db.js";
import { getSupplementKeyword } from "./affiliate-keywords.js";
import type { User } from "../models/user.js";
import type { HealthRecord } from "../models/health-record.js";
import type { Bot } from "grammy";

/**
 * Build and send the morning digest message to a single user.
 */
async function sendDigestToUser(bot: Bot, user: User): Promise<void> {
  const db = getDb();
  const userId = user._id.toString();
  const telegramId = user.telegram_id;
  if (!telegramId) return;

  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayStr = yesterday.toISOString().slice(0, 10);
  const todayStr = new Date().toISOString().slice(0, 10);

  // Fetch yesterday's metric, today's quick log, and latest supplement protocol
  const [metric, quickLog, latestRecord] = await Promise.all([
    db.collection("daily_metrics").findOne({ user_id: userId, date: yesterdayStr }),
    db.collection("quick_logs").findOne({ user_id: userId, date: todayStr }),
    db.collection<HealthRecord>("health_records").findOne(
      {
        user_id: user._id,
        status: "completed",
        supplement_protocol: { $exists: true, $ne: [] },
      },
      { sort: { created_at: -1 } },
    ),
  ]);

  // Calculate logging streak
  const logDates = await db
    .collection("quick_logs")
    .find({ user_id: userId }, { projection: { date: 1, _id: 0 } })
    .sort({ date: -1 })
    .limit(14)
    .toArray();

  const dateSet = new Set(logDates.map((l) => l.date as string));
  let streak = 0;
  const cursor = new Date();
  while (dateSet.has(cursor.toISOString().slice(0, 10))) {
    streak++;
    cursor.setDate(cursor.getDate() - 1);
  }

  // Build message
  const lines: string[] = ["*Good morning! Here's your health digest:*\n"];

  // Yesterday's metrics
  if (metric) {
    if (typeof metric.steps === "number")
      lines.push(`Steps: ${metric.steps.toLocaleString()}`);
    if (typeof metric.sleep_hours === "number") {
      const sleepEmoji = metric.sleep_hours >= 7 ? "Great" : metric.sleep_hours >= 6 ? "OK" : "Low";
      lines.push(`Sleep: ${metric.sleep_hours.toFixed(1)}h (${sleepEmoji})`);
    }
    if (typeof metric.resting_heart_rate === "number")
      lines.push(`Resting HR: ${metric.resting_heart_rate} bpm`);
    if (typeof metric.hrv_avg === "number")
      lines.push(`HRV: ${metric.hrv_avg.toFixed(0)} ms`);
  } else {
    lines.push("_No HealthKit data from yesterday._");
  }

  lines.push(`\nStreak: ${streak} days`);

  // Supplement schedule
  const supplements = (latestRecord?.supplement_protocol as any[]) ?? [];
  if (supplements.length > 0) {
    lines.push("\n*Today's supplements:*");

    // Group by timing
    const timingOrder = [
      "morning_empty_stomach",
      "morning_with_food",
      "afternoon",
      "evening_with_food",
      "evening_before_bed",
    ];

    const timingLabels: Record<string, string> = {
      morning_empty_stomach: "7:00 AM",
      morning_with_food: "8:00 AM",
      afternoon: "2:00 PM",
      evening_with_food: "7:00 PM",
      evening_before_bed: "10:00 PM",
    };

    const grouped = new Map<string, string[]>();
    for (const supp of supplements) {
      const kw = getSupplementKeyword(supp.name ?? "");
      const timing = kw.timing;
      if (!grouped.has(timing)) grouped.set(timing, []);
      grouped.get(timing)!.push(supp.name ?? "Unknown");
    }

    for (const timing of timingOrder) {
      const names = grouped.get(timing);
      if (names && names.length > 0) {
        const label = timingLabels[timing] ?? timing;
        lines.push(`  ${label} -- ${names.join(", ")}`);
      }
    }
  }

  // Motivation
  if (!quickLog) {
    lines.push("\nDon't forget to log your mood today! /log");
  }

  lines.push("\nHave a great day!");

  try {
    await bot.api.sendMessage(telegramId, lines.join("\n"), {
      parse_mode: "Markdown",
    });
  } catch (err) {
    console.error(`[Digest] Failed to send to ${telegramId}:`, err);
  }
}

/**
 * Send the daily morning digest to all linked Telegram users.
 */
export async function sendDailyDigest(bot: Bot): Promise<void> {
  const db = getDb();

  const linkedUsers = await db
    .collection<User>("users")
    .find({
      telegram_id: { $ne: null },
      is_active: true,
    })
    .toArray();

  console.log(`[Digest] Sending morning digest to ${linkedUsers.length} users`);

  for (const user of linkedUsers) {
    try {
      await sendDigestToUser(bot, user);
    } catch (err) {
      console.error(`[Digest] Error for user ${user._id}:`, err);
    }
  }
}

/**
 * Start the daily digest scheduler.
 * Checks every minute if it's 08:00 and sends the digest.
 */
export function startDigestScheduler(bot: Bot): void {
  let lastSentDate = "";

  setInterval(async () => {
    const now = new Date();
    const hour = now.getHours();
    const minute = now.getMinutes();
    const dateStr = now.toISOString().slice(0, 10);

    // Send at 08:00, only once per day
    if (hour === 8 && minute === 0 && dateStr !== lastSentDate) {
      lastSentDate = dateStr;
      console.log(`[Digest] Triggering daily digest for ${dateStr}`);
      try {
        await sendDailyDigest(bot);
      } catch (err) {
        console.error("[Digest] Scheduler error:", err);
      }
    }
  }, 60_000); // Check every minute

  console.log("[Digest] Daily digest scheduler started (08:00 daily)");
}

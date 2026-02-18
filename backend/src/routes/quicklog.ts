import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { getDb } from "../db.js";
import { getCurrentUser } from "../middleware/auth.js";
import { quickLogSchema, logQuerySchema, calendarQuerySchema } from "../schemas/quicklog.js";

const quicklog = new Hono();

// ===== POST /quick =====
// Upsert daily quick log (one per user per day)

quicklog.post("/quick", async (c) => {
  const user = await getCurrentUser(c);
  const body = await c.req.json();
  const parsed = quickLogSchema.safeParse(body);

  if (!parsed.success) {
    throw new HTTPException(400, { message: "Invalid request body" });
  }

  const db = getDb();
  const collection = db.collection("quick_logs");
  const userId = user._id.toString();
  const todayStr = new Date().toISOString().slice(0, 10);

  const result = await collection.updateOne(
    { user_id: userId, date: todayStr },
    {
      $set: {
        ...parsed.data,
        user_id: userId,
        date: todayStr,
        updated_at: new Date(),
      },
      $setOnInsert: {
        created_at: new Date(),
      },
    },
    { upsert: true }
  );

  const isNew = result.upsertedCount > 0;

  return c.json({
    status: isNew ? "created" : "updated",
    date: todayStr,
  });
});

// ===== GET / =====
// Paginated log history (last N days)

quicklog.get("/", async (c) => {
  const user = await getCurrentUser(c);
  const queryParsed = logQuerySchema.safeParse({ days: c.req.query("days") });

  if (!queryParsed.success) {
    throw new HTTPException(400, { message: "Invalid query parameters" });
  }

  const { days } = queryParsed.data;
  const userId = user._id.toString();
  const db = getDb();

  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - days);
  const cutoffStr = cutoff.toISOString().slice(0, 10);

  const logs = await db
    .collection("quick_logs")
    .find({ user_id: userId, date: { $gte: cutoffStr } })
    .sort({ date: -1 })
    .toArray();

  return c.json({ days_requested: days, count: logs.length, logs });
});

// ===== GET /streak =====
// Current consecutive streak and longest streak

quicklog.get("/streak", async (c) => {
  const user = await getCurrentUser(c);
  const userId = user._id.toString();
  const db = getDb();

  // Fetch all log dates sorted descending
  const logs = await db
    .collection("quick_logs")
    .find({ user_id: userId }, { projection: { date: 1, _id: 0 } })
    .sort({ date: -1 })
    .toArray();

  if (logs.length === 0) {
    return c.json({ current_streak: 0, longest_streak: 0 });
  }

  const dateSet = new Set(logs.map((l) => l.date as string));

  // Current streak: count consecutive days backwards from today
  let currentStreak = 0;
  const today = new Date();
  const cursor = new Date(today);

  while (true) {
    const dateStr = cursor.toISOString().slice(0, 10);
    if (dateSet.has(dateStr)) {
      currentStreak++;
      cursor.setDate(cursor.getDate() - 1);
    } else {
      break;
    }
  }

  // Longest streak: iterate all dates in order
  const sortedDates = Array.from(dateSet).sort();
  let longestStreak = 1;
  let runLength = 1;

  for (let i = 1; i < sortedDates.length; i++) {
    const prev = new Date(sortedDates[i - 1]);
    const curr = new Date(sortedDates[i]);
    const diffMs = curr.getTime() - prev.getTime();
    const diffDays = Math.round(diffMs / (1000 * 60 * 60 * 24));

    if (diffDays === 1) {
      runLength++;
      if (runLength > longestStreak) longestStreak = runLength;
    } else {
      runLength = 1;
    }
  }

  return c.json({ current_streak: currentStreak, longest_streak: longestStreak });
});

// ===== GET /calendar =====
// Month of mood/energy data for heatmap display

quicklog.get("/calendar", async (c) => {
  const user = await getCurrentUser(c);
  const queryParsed = calendarQuerySchema.safeParse({ month: c.req.query("month") });

  if (!queryParsed.success) {
    throw new HTTPException(400, { message: "Invalid month parameter. Expected format: YYYY-MM" });
  }

  const { month } = queryParsed.data;
  const userId = user._id.toString();
  const db = getDb();

  // Build date range for the month
  const startDate = `${month}-01`;
  const [yearStr, monthStr] = month.split("-");
  const year = parseInt(yearStr, 10);
  const mon = parseInt(monthStr, 10);
  // Last day of the month
  const lastDay = new Date(year, mon, 0).getDate();
  const endDate = `${month}-${String(lastDay).padStart(2, "0")}`;

  const logs = await db
    .collection("quick_logs")
    .find(
      { user_id: userId, date: { $gte: startDate, $lte: endDate } },
      { projection: { date: 1, mood: 1, energy: 1, _id: 0 } }
    )
    .sort({ date: 1 })
    .toArray();

  return c.json({ month, entries: logs });
});

export default quicklog;

import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { getDb } from "../db.js";
import { getCurrentUser } from "../middleware/auth.js";
import { syncHealthKitSchema, summaryQuerySchema } from "../schemas/healthkit.js";
import { RecordStatus } from "../models/health-record.js";
import type { HealthRecord } from "../models/health-record.js";

const healthkit = new Hono();

// ===== POST /sync =====
// Batch upsert daily HealthKit metrics (up to 90 days)

healthkit.post("/sync", async (c) => {
  const user = await getCurrentUser(c);
  const body = await c.req.json();
  const parsed = syncHealthKitSchema.safeParse(body);

  if (!parsed.success) {
    throw new HTTPException(400, { message: "Invalid request body" });
  }

  const db = getDb();
  const collection = db.collection("daily_metrics");
  const userId = user._id.toString();

  const bulkOps = parsed.data.metrics.map((metric) => ({
    updateOne: {
      filter: { user_id: userId, date: metric.date },
      update: {
        $set: {
          ...metric,
          user_id: userId,
          updated_at: new Date(),
        },
        $setOnInsert: {
          created_at: new Date(),
        },
      },
      upsert: true,
    },
  }));

  const result = await collection.bulkWrite(bulkOps);

  return c.json({
    upserted: result.upsertedCount,
    modified: result.modifiedCount,
    total: parsed.data.metrics.length,
  });
});

// ===== GET /summary =====
// Get last N days of metrics with computed averages

healthkit.get("/summary", async (c) => {
  const user = await getCurrentUser(c);
  const queryParsed = summaryQuerySchema.safeParse({ days: c.req.query("days") });

  if (!queryParsed.success) {
    throw new HTTPException(400, { message: "Invalid query parameters" });
  }

  const { days } = queryParsed.data;
  const userId = user._id.toString();
  const db = getDb();
  const collection = db.collection("daily_metrics");

  // Calculate the cutoff date string (YYYY-MM-DD)
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - days);
  const cutoffStr = cutoff.toISOString().slice(0, 10);

  const metrics = await collection
    .find({ user_id: userId, date: { $gte: cutoffStr } })
    .sort({ date: -1 })
    .toArray();

  // Compute averages from available data
  const count = metrics.length;
  if (count === 0) {
    return c.json({ days_requested: days, days_with_data: 0, metrics: [], averages: null });
  }

  const sum = (field: string) => {
    const values = metrics
      .map((m) => m[field])
      .filter((v): v is number => typeof v === "number");
    return values.length > 0 ? values.reduce((a, b) => a + b, 0) / values.length : null;
  };

  const averages = {
    steps: sum("steps"),
    active_energy_kcal: sum("active_energy_kcal"),
    sleep_hours: sum("sleep_hours"),
    heart_rate_avg: sum("heart_rate_avg"),
    resting_heart_rate: sum("resting_heart_rate"),
    hrv_avg: sum("hrv_avg"),
  };

  return c.json({
    days_requested: days,
    days_with_data: count,
    metrics,
    averages,
  });
});

// ===== GET /today =====
// Get today's metric entry

healthkit.get("/today", async (c) => {
  const user = await getCurrentUser(c);
  const userId = user._id.toString();
  const db = getDb();

  const todayStr = new Date().toISOString().slice(0, 10);

  const metric = await db
    .collection("daily_metrics")
    .findOne({ user_id: userId, date: todayStr });

  if (!metric) {
    return c.json({ date: todayStr, data: null });
  }

  return c.json({ date: todayStr, data: metric });
});

// ===== GET /vitality =====
// Calculates a 0-100 Vitality Score from five data pillars:
// Sleep (30%), Recovery (25%), Activity (20%), Clinical (15%), Consistency (10%)

// --- Vitality Score helper functions ---

/** Linear interpolation: maps `value` from [minVal, maxVal] to [minScore, maxScore], clamped. */
function lerp(value: number, minVal: number, maxVal: number, minScore: number, maxScore: number): number {
  if (maxVal === minVal) return maxScore;
  const t = (value - minVal) / (maxVal - minVal);
  const clamped = Math.max(0, Math.min(1, t));
  return Math.round(minScore + clamped * (maxScore - minScore));
}

/** Sleep score: 7-9h = 100, <5h = 20, >10h = 60, linear interpolation between. */
function scoreSleep(hours: number): number {
  if (hours >= 7 && hours <= 9) return 100;
  if (hours < 7) return lerp(hours, 5, 7, 20, 100);
  // hours > 9
  return lerp(hours, 9, 10, 100, 60);
}

/** HRV score: >60ms = 100, <20ms = 20, linear between. */
function scoreHrv(hrv: number): number {
  if (hrv >= 60) return 100;
  if (hrv <= 20) return 20;
  return lerp(hrv, 20, 60, 20, 100);
}

/** RHR score: <60 = 100, >80 = 30, linear between. */
function scoreRhr(rhr: number): number {
  if (rhr <= 60) return 100;
  if (rhr >= 80) return 30;
  return lerp(rhr, 60, 80, 100, 30);
}

/** Activity score: >=8000 steps = 100, <2000 = 20, linear between. */
function scoreActivity(steps: number): number {
  if (steps >= 8000) return 100;
  if (steps <= 2000) return 20;
  return lerp(steps, 2000, 8000, 20, 100);
}

/** Consistency score: >=7 day streak = 100, 0 = 0, linear between. */
function scoreConsistency(streak: number): number {
  if (streak >= 7) return 100;
  if (streak <= 0) return 0;
  return Math.round((streak / 7) * 100);
}

/** Compute the current consecutive log streak (days backwards from a given date). */
function computeStreak(dateSet: Set<string>, fromDate: Date): number {
  let streak = 0;
  const cursor = new Date(fromDate);
  while (true) {
    const dateStr = cursor.toISOString().slice(0, 10);
    if (dateSet.has(dateStr)) {
      streak++;
      cursor.setDate(cursor.getDate() - 1);
    } else {
      break;
    }
  }
  return streak;
}

/** Format a Date to YYYY-MM-DD string. */
function toDateStr(d: Date): string {
  return d.toISOString().slice(0, 10);
}

interface VitalityComponent {
  score: number;
  weight: number;
  value: string;
  available: boolean;
}

interface ComponentDef {
  key: string;
  baseWeight: number;
}

const COMPONENT_DEFS: ComponentDef[] = [
  { key: "sleep", baseWeight: 0.30 },
  { key: "recovery", baseWeight: 0.25 },
  { key: "activity", baseWeight: 0.20 },
  { key: "clinical", baseWeight: 0.15 },
  { key: "consistency", baseWeight: 0.10 },
];

/**
 * Calculate Vitality Score for a single day given the available data.
 * Returns the overall score and component breakdown.
 */
function calculateVitality(
  metric: Record<string, any> | null,
  wellnessScore: number | null,
  logStreak: number,
): { score: number; components: Record<string, VitalityComponent> } {

  const raw: Record<string, { score: number; value: string; available: boolean }> = {};

  // Sleep
  const sleepHours = metric?.sleep_hours;
  if (typeof sleepHours === "number") {
    raw.sleep = { score: scoreSleep(sleepHours), value: `${sleepHours}h`, available: true };
  } else {
    raw.sleep = { score: 0, value: "No data", available: false };
  }

  // Recovery (HRV + RHR)
  const hrvAvg = metric?.hrv_avg;
  const rhr = metric?.resting_heart_rate;
  if (typeof hrvAvg === "number" || typeof rhr === "number") {
    let recoveryScore: number;
    const parts: string[] = [];
    if (typeof hrvAvg === "number" && typeof rhr === "number") {
      recoveryScore = Math.round((scoreHrv(hrvAvg) + scoreRhr(rhr)) / 2);
      parts.push(`HRV ${hrvAvg}ms`, `RHR ${rhr}`);
    } else if (typeof hrvAvg === "number") {
      recoveryScore = scoreHrv(hrvAvg);
      parts.push(`HRV ${hrvAvg}ms`);
    } else {
      recoveryScore = scoreRhr(rhr as number);
      parts.push(`RHR ${rhr}`);
    }
    raw.recovery = { score: recoveryScore, value: parts.join(" / "), available: true };
  } else {
    raw.recovery = { score: 0, value: "No data", available: false };
  }

  // Activity
  const steps = metric?.steps;
  if (typeof steps === "number") {
    raw.activity = { score: scoreActivity(steps), value: `${steps} steps`, available: true };
  } else {
    raw.activity = { score: 0, value: "No data", available: false };
  }

  // Clinical
  if (typeof wellnessScore === "number" && wellnessScore > 0) {
    raw.clinical = { score: Math.round(wellnessScore), value: "Blood work", available: true };
  } else {
    raw.clinical = { score: 0, value: "No data", available: false };
  }

  // Consistency
  raw.consistency = {
    score: scoreConsistency(logStreak),
    value: `${logStreak}-day streak`,
    available: true, // streak of 0 is still a valid data point
  };

  // Weight redistribution: gather available components and redistribute
  const availableWeight = COMPONENT_DEFS
    .filter((d) => raw[d.key].available)
    .reduce((sum, d) => sum + d.baseWeight, 0);

  const components: Record<string, VitalityComponent> = {};
  let totalScore = 0;

  for (const def of COMPONENT_DEFS) {
    const r = raw[def.key];
    const effectiveWeight = r.available && availableWeight > 0
      ? def.baseWeight / availableWeight
      : 0;
    components[def.key] = {
      score: r.score,
      weight: Math.round(effectiveWeight * 100) / 100,
      value: r.value,
      available: r.available,
    };
    if (r.available) {
      totalScore += r.score * effectiveWeight;
    }
  }

  return {
    score: Math.round(totalScore),
    components,
  };
}

healthkit.get("/vitality", async (c) => {
  const user = await getCurrentUser(c);
  const userId = user._id.toString();
  const db = getDb();

  const today = new Date();
  const todayStr = toDateStr(today);

  // Fetch data in parallel: today's metric, last 7 days of metrics, latest health record, log dates
  const sevenDaysAgo = new Date(today);
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
  const cutoffStr = toDateStr(sevenDaysAgo);

  const [metricsLast7, latestRecord, logDocs] = await Promise.all([
    // Last 8 days of metrics (today + 7 prior days for trend)
    db.collection("daily_metrics")
      .find({ user_id: userId, date: { $gte: cutoffStr } })
      .sort({ date: -1 })
      .toArray(),

    // Latest completed health record with a wellness_score
    db.collection<HealthRecord>("health_records")
      .findOne(
        {
          user_id: user._id,
          status: RecordStatus.COMPLETED,
          wellness_score: { $exists: true, $ne: null },
        },
        { sort: { created_at: -1 }, projection: { wellness_score: 1 } }
      ),

    // All log dates for streak calculation (last 30 days is sufficient)
    (() => {
      const streakCutoff = new Date(today);
      streakCutoff.setDate(streakCutoff.getDate() - 30);
      return db.collection("quick_logs")
        .find(
          { user_id: userId, date: { $gte: toDateStr(streakCutoff) } },
          { projection: { date: 1, _id: 0 } }
        )
        .sort({ date: -1 })
        .toArray();
    })(),
  ]);

  // Build a map of date -> metric for quick lookup
  const metricsByDate = new Map<string, Record<string, any>>();
  for (const m of metricsLast7) {
    metricsByDate.set(m.date as string, m);
  }

  // Build set of log dates for streak calculation
  const logDateSet = new Set(logDocs.map((l) => l.date as string));

  // Clinical wellness score (shared across all days since it is from latest blood work)
  const wellnessScore = (latestRecord?.wellness_score as number | undefined) ?? null;

  // Calculate today's vitality score
  const todayMetric = metricsByDate.get(todayStr) ?? null;
  const currentStreak = computeStreak(logDateSet, today);
  const todayResult = calculateVitality(todayMetric, wellnessScore, currentStreak);

  // Calculate 7-day trend (each of the last 7 days, not including today if already covered)
  const trend: { date: string; score: number }[] = [];
  for (let i = 7; i >= 1; i--) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    const dateStr = toDateStr(d);
    const dayMetric = metricsByDate.get(dateStr) ?? null;
    const dayStreak = computeStreak(logDateSet, d);
    const dayResult = calculateVitality(dayMetric, wellnessScore, dayStreak);
    trend.push({ date: dateStr, score: dayResult.score });
  }
  // Add today as the last point
  trend.push({ date: todayStr, score: todayResult.score });

  return c.json({
    vitality_score: todayResult.score,
    components: todayResult.components,
    trend,
  });
});

export default healthkit;

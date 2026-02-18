import { getDb } from "../db.js";
import type { User } from "../models/user.js";
import type { HealthRecord, BiomarkerData } from "../models/health-record.js";
import { calculateAge } from "../models/user.js";

export interface ChatContext {
  systemPrompt: string;
  userSummary: string;
}

export async function buildChatContext(user: User): Promise<ChatContext> {
  const db = getDb();
  const userId = user._id.toString();
  const todayStr = new Date().toISOString().slice(0, 10);

  // Fetch all relevant data in parallel
  const [latestRecord, todayMetric, recentLogs, weekMetrics] = await Promise.all([
    // Latest completed health record with biomarkers
    db.collection<HealthRecord>("health_records").findOne(
      { user_id: user._id, status: "completed", biomarkers: { $exists: true, $ne: [] } },
      { sort: { created_at: -1 } }
    ),
    // Today's HealthKit metric
    db.collection("daily_metrics").findOne({ user_id: userId, date: todayStr }),
    // Last 7 quick logs
    db.collection("quick_logs").find({ user_id: userId }).sort({ date: -1 }).limit(7).toArray(),
    // Last 7 days of HealthKit metrics
    (() => {
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() - 7);
      return db.collection("daily_metrics")
        .find({ user_id: userId, date: { $gte: cutoff.toISOString().slice(0, 10) } })
        .sort({ date: -1 }).toArray();
    })(),
  ]);

  // Build user profile section
  const age = calculateAge(user.date_of_birth);
  const profileParts: string[] = [];
  if (age) profileParts.push(`Age: ${age}`);
  if (user.gender) profileParts.push(`Gender: ${user.gender}`);
  if (user.dietary_preference && user.dietary_preference !== "omnivore") profileParts.push(`Diet: ${user.dietary_preference}`);
  if (user.allergies?.length) profileParts.push(`Allergies: ${user.allergies.join(", ")}`);
  if (user.health_goals?.length) profileParts.push(`Goals: ${user.health_goals.join(", ")}`);
  if (user.health_conditions?.length) profileParts.push(`Conditions: ${user.health_conditions.join(", ")}`);

  // Build biomarker section
  let biomarkerSection = "";
  if (latestRecord?.biomarkers?.length) {
    const biomarkers = latestRecord.biomarkers as BiomarkerData[];
    const flagged = biomarkers.filter(b => b.status === "high" || b.status === "low");
    const optimal = biomarkers.filter(b => b.status === "optimal");

    biomarkerSection = `\n## Latest Blood Work (${latestRecord.record_date ? new Date(latestRecord.record_date).toISOString().slice(0, 10) : "recent"})\n`;
    if (flagged.length) {
      biomarkerSection += `Flagged:\n${flagged.map(b => `- ${b.name}: ${b.value} ${b.unit} (${b.status})`).join("\n")}\n`;
    }
    if (optimal.length) {
      biomarkerSection += `Optimal: ${optimal.map(b => b.name).join(", ")}\n`;
    }
    if (latestRecord.wellness_score != null) {
      biomarkerSection += `Wellness Score: ${latestRecord.wellness_score}/100\n`;
    }
    if (latestRecord.supplement_protocol?.length) {
      biomarkerSection += `\nSupplement Protocol:\n${(latestRecord.supplement_protocol as any[]).map(s => `- ${s.name}: ${s.dosage} (${s.reason})`).join("\n")}\n`;
    }
  }

  // Build HealthKit section
  let healthkitSection = "";
  if (todayMetric || weekMetrics.length) {
    healthkitSection = "\n## HealthKit Data\n";
    if (todayMetric) {
      healthkitSection += `Today: `;
      const parts: string[] = [];
      if (typeof todayMetric.steps === "number") parts.push(`${todayMetric.steps} steps`);
      if (typeof todayMetric.sleep_hours === "number") parts.push(`${todayMetric.sleep_hours.toFixed(1)}h sleep`);
      if (typeof todayMetric.resting_heart_rate === "number") parts.push(`RHR ${todayMetric.resting_heart_rate}`);
      if (typeof todayMetric.hrv_avg === "number") parts.push(`HRV ${todayMetric.hrv_avg.toFixed(0)}ms`);
      healthkitSection += parts.join(", ") + "\n";
    }
    if (weekMetrics.length > 1) {
      const stepsMetrics = weekMetrics.filter(m => typeof m.steps === "number");
      const sleepMetrics = weekMetrics.filter(m => typeof m.sleep_hours === "number");
      const avgSteps = stepsMetrics.length
        ? stepsMetrics.reduce((s, m) => s + (m.steps as number), 0) / stepsMetrics.length
        : 0;
      const avgSleep = sleepMetrics.length
        ? sleepMetrics.reduce((s, m) => s + (m.sleep_hours as number), 0) / sleepMetrics.length
        : 0;
      healthkitSection += `7-day avg: ${Math.round(avgSteps)} steps, ${avgSleep.toFixed(1)}h sleep\n`;
    }
  }

  // Build mood/log section
  let logSection = "";
  if (recentLogs.length) {
    logSection = "\n## Recent Mood/Energy Logs\n";
    const moods = ["Terrible", "Bad", "Okay", "Good", "Great"];
    for (const log of recentLogs.slice(0, 5)) {
      const moodStr = moods[(log.mood as number) - 1] ?? "?";
      logSection += `${log.date}: Mood=${moodStr}, Energy=${log.energy}/5`;
      if (log.symptoms?.length) logSection += `, Symptoms: ${(log.symptoms as string[]).join(", ")}`;
      logSection += "\n";
    }
  }

  const userSummary = [
    profileParts.length ? `## User Profile\n${profileParts.join("\n")}` : "",
    biomarkerSection,
    healthkitSection,
    logSection,
  ].filter(Boolean).join("\n");

  const systemPrompt = `You are HealthWallet AI, a friendly health and wellness assistant. You have access to the user's health data and provide personalized guidance.

RESPONSE STYLE — THIS IS A MOBILE CHAT APP:
- Reply in 1-3 SHORT sentences by default. Think text message, not essay.
- Use bullet points for lists (max 3-4 items).
- Only give longer answers if the user explicitly asks for detail or says "explain more".
- Never use headers (##) or long paragraphs. Keep it conversational.
- Reference their actual data briefly (e.g., "Your Vitamin D is low at 22 ng/mL").
- End with one actionable next step when relevant.

SAFETY RULES:
1. You are NOT a doctor. Never diagnose or prescribe.
2. Frame advice as "wellness optimization" — suggest consulting a doctor for medical concerns.
3. If asked about something outside your data, say so briefly.
4. Consider their dietary preferences and allergies for food advice.

## USER'S HEALTH CONTEXT
${userSummary || "No health data available yet. Encourage them to upload blood work or sync HealthKit."}`;

  return { systemPrompt, userSummary };
}

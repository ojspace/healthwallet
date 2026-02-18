import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";
import { HTTPException } from "hono/http-exception";
import { ObjectId } from "mongodb";
import { randomUUID } from "crypto";
import { writeFile, mkdir } from "fs/promises";
import { join, extname } from "path";
import { getDb } from "../db.js";
import { config } from "../config.js";
import { getCurrentUser } from "../middleware/auth.js";
import { calculateAge } from "../models/user.js";
import { RecordStatus, calculateWellnessScore, calculateHealthAge, createDefaultRecord } from "../models/health-record.js";
import { FREE_UPLOAD_LIMIT, isPro } from "../utils/subscription.js";
import type { HealthRecord } from "../models/health-record.js";
import type { User } from "../models/user.js";
import { processRecordAsync } from "../services/process-record.js";
import { detectCorrelations, getSupplementProtocol } from "../services/lab-parser.js";
import {
  verifyRecordRequestSchema,
  listRecordsQuerySchema,
  doctorBriefRequestSchema,
} from "../schemas/records.js";

const records = new Hono();

function recordToResponse(record: HealthRecord, options?: { isPro: boolean }) {
  const pro = options?.isPro ?? false;
  const foodRecommendations = record.food_recommendations ?? [];
  const supplementProtocol = record.supplement_protocol ?? [];

  return {
    id: record._id.toHexString(),
    status: record.status,
    original_filename: record.original_filename,
    record_date: record.record_date?.toISOString() ?? null,
    lab_provider: record.lab_provider,
    record_type: record.record_type,
    biomarkers: record.biomarkers,
    summary: record.summary,
    correlations: record.correlations,
    key_findings: record.key_findings,
    recommendations: record.recommendations,
    food_recommendations: pro ? foodRecommendations : foodRecommendations.slice(0, 3),
    supplement_protocol: pro ? supplementProtocol : [],
    wellness_score: record.wellness_score,
    health_age: record.health_age,
    error_message: record.error_message,
    created_at: record.created_at.toISOString(),
    updated_at: record.updated_at.toISOString(),
  };
}

// ===== Upload =====

records.post("/upload", async (c) => {
  const user = await getCurrentUser(c);

  const pro = isPro(user);
  if (!pro && (user.upload_count ?? 0) >= FREE_UPLOAD_LIMIT) {
    throw new HTTPException(403, { message: "Free upload limit reached. Upgrade to Pro for unlimited uploads." });
  }

  const body = await c.req.parseBody();
  const file = body["file"];

  if (!file || !(file instanceof File)) {
    throw new HTTPException(400, { message: "No file uploaded" });
  }

  if (!file.name.toLowerCase().endsWith(".pdf")) {
    throw new HTTPException(400, { message: "Only PDF files are accepted" });
  }

  const maxSize = config.maxUploadSizeMb * 1024 * 1024;
  if (file.size > maxSize) {
    throw new HTTPException(400, { message: `File size exceeds maximum allowed (${config.maxUploadSizeMb}MB)` });
  }

  // Save file
  await mkdir(config.uploadDir, { recursive: true });
  const ext = extname(file.name);
  const uniqueFilename = `${randomUUID()}${ext}`;
  const filePath = join(config.uploadDir, uniqueFilename);
  const buffer = await file.arrayBuffer();
  await writeFile(filePath, Buffer.from(buffer));

  // Create record
  const db = getDb();
  const collection = db.collection<HealthRecord>("health_records");
  const recordData = createDefaultRecord({
    user_id: user._id,
    file_url: filePath,
    original_filename: file.name,
  });

  const result = await collection.insertOne(recordData as any);
  const recordId = result.insertedId.toHexString();

  // Increment upload count
  const usersCol = db.collection<User>("users");
  await usersCol.updateOne(
    { _id: user._id },
    { $inc: { upload_count: 1 }, $set: { updated_at: new Date() } }
  );

  // Process synchronously in debug mode
  if (config.debug) {
    console.log("[Upload] DEBUG mode - processing synchronously");
    try {
      await processRecordAsync(recordId, user.dietary_preference, calculateAge(user.date_of_birth));
    } catch (err) {
      console.error("[Upload] Processing failed:", err);
    }
  }

  // Refresh record to get updated status
  const record = await collection.findOne({ _id: result.insertedId });

  c.status(202);
  return c.json({
    record_id: recordId,
    status: record?.status ?? RecordStatus.UPLOADING,
    message: "File uploaded successfully. Processing started.",
  });
});

// ===== Dashboard (must come before /:record_id) =====

records.get("/dashboard/summary", async (c) => {
  const user = await getCurrentUser(c);
  const pro = isPro(user);
  const db = getDb();
  const collection = db.collection<HealthRecord>("health_records");

  const completedRecords = await collection
    .find({ user_id: user._id, status: RecordStatus.COMPLETED })
    .sort({ created_at: -1 })
    .toArray();

  if (!completedRecords.length) {
    return c.json({
      wellness_score: 0,
      health_age: null,
      chronological_age: null,
      last_sync: "No records",
      summary: null,
      score_breakdown: {},
      biomarker_trends: [],
      key_findings: [],
      correlations: [],
      action_plan: [],
      supplement_protocol: [],
      total_records: 0,
      is_pro: pro,
    });
  }

  const latest = completedRecords[0];

  // Build biomarker trends
  const biomarkerHistory: Record<string, { date: Date; value: any; status: any }[]> = {};
  for (const record of completedRecords.slice(0, 10)) {
    for (const biomarker of record.biomarkers) {
      const name = biomarker.name ?? "";
      if (!biomarkerHistory[name]) biomarkerHistory[name] = [];
      biomarkerHistory[name].push({
        date: record.record_date ?? record.created_at,
        value: biomarker.value,
        status: biomarker.status,
      });
    }
  }

  const biomarkerTrends: Record<string, any>[] = [];
  for (const [name, history] of Object.entries(biomarkerHistory)) {
    if (history.length >= 1) {
      const latestPoint = history[0];
      biomarkerTrends.push({
        id: name.toLowerCase().replace(/ /g, "_"),
        title: name,
        value: latestPoint.value,
        unit: latest.biomarkers.find(b => b.name === name)?.unit ?? "",
        status: latestPoint.status,
        trend_points: history.slice(0, 5).reverse().map(h => h.value),
      });
    }
  }

  // Score breakdown by category
  const categoryScores: Record<string, number[]> = {};
  for (const biomarker of latest.biomarkers) {
    const category = biomarker.category ?? "other";
    const score = biomarker.status === "optimal" ? 100 : 70;
    if (!categoryScores[category]) categoryScores[category] = [];
    categoryScores[category].push(score);
  }

  const scoreBreakdown: Record<string, number> = {};
  for (const [category, scores] of Object.entries(categoryScores)) {
    scoreBreakdown[category] = scores.length ? Math.round(scores.reduce((a, b) => a + b, 0) / scores.length) : 0;
  }

  // Action plan from food recommendations
  const actionPlan = (latest.food_recommendations ?? []).slice(0, 4).map(rec => ({
    id: randomUUID(),
    title: rec.food ?? "",
    subtitle: rec.reason ?? "",
    is_completed: false,
    type: "recipe",
  }));

  // Paywall removed — all data available to all users
  return c.json({
    wellness_score: latest.wellness_score ?? calculateWellnessScore(latest.biomarkers),
    health_age: latest.health_age,
    chronological_age: calculateAge(user.date_of_birth),
    last_sync: latest.updated_at.toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" }),
    summary: latest.summary,
    score_breakdown: scoreBreakdown,
    biomarker_trends: biomarkerTrends.slice(0, 6),
    key_findings: latest.key_findings,
    correlations: latest.correlations,
    action_plan: actionPlan,
    supplement_protocol: pro ? (latest.supplement_protocol ?? []) : [],
    total_records: completedRecords.length,
    is_pro: pro,
  });
});

// ===== Comparison =====

records.get("/comparison", async (c) => {
  const user = await getCurrentUser(c);

  if (!isPro(user)) {
    throw new HTTPException(403, { message: "Upgrade to Pro to access year-over-year comparison" });
  }

  const db = getDb();
  const collection = db.collection<HealthRecord>("health_records");

  const completedRecords = await collection
    .find({ user_id: user._id, status: RecordStatus.COMPLETED })
    .sort({ created_at: -1 })
    .toArray();

  if (completedRecords.length < 2) {
    throw new HTTPException(400, { message: "Need at least 2 records for comparison" });
  }

  const biomarkerData: Record<string, { name: string; unit: string; data_points: any[] }> = {};

  for (const record of completedRecords) {
    const recordDate = record.record_date ?? record.created_at;
    for (const biomarker of record.biomarkers) {
      const name = biomarker.name ?? "";
      if (!biomarkerData[name]) {
        biomarkerData[name] = { name, unit: biomarker.unit ?? "", data_points: [] };
      }
      biomarkerData[name].data_points.push({
        date: recordDate.toISOString(),
        value: biomarker.value,
        status: biomarker.status,
      });
    }
  }

  const trends = [];
  for (const data of Object.values(biomarkerData)) {
    const points = data.data_points;
    if (points.length >= 2) {
      const latestVal = points[0].value;
      const oldestVal = points[points.length - 1].value;
      const change = oldestVal && oldestVal !== 0 ? ((latestVal - oldestVal) / oldestVal) * 100 : 0;

      let trend = "stable";
      if (Math.abs(change) > 5) {
        const goodWhenHigh = ["hdl", "vitamin d", "iron", "vitamin b12"];
        const isGoodHigh = goodWhenHigh.some(g => data.name.toLowerCase().includes(g));
        if (change > 0) trend = isGoodHigh ? "improving" : "worsening";
        else trend = isGoodHigh ? "worsening" : "improving";
      }

      trends.push({
        name: data.name,
        unit: data.unit,
        data_points: points,
        change_percent: Math.round(change * 10) / 10,
        trend,
      });
    }
  }

  const dates = completedRecords.map(r => r.record_date ?? r.created_at);

  return c.json({
    biomarker_trends: trends,
    records_compared: completedRecords.length,
    date_range: {
      start: new Date(Math.min(...dates.map(d => d.getTime()))).toISOString(),
      end: new Date(Math.max(...dates.map(d => d.getTime()))).toISOString(),
    },
  });
});

// ===== Doctor Brief Export =====

records.post("/export/doctor-brief", zValidator("json", doctorBriefRequestSchema), async (c) => {
  const user = await getCurrentUser(c);

  if (!isPro(user)) {
    throw new HTTPException(403, { message: "Upgrade to Pro to export a doctor brief" });
  }

  const body = c.req.valid("json");
  const db = getDb();
  const collection = db.collection<HealthRecord>("health_records");

  const completedRecords = await collection
    .find({ user_id: user._id, status: RecordStatus.COMPLETED })
    .sort({ created_at: -1 })
    .limit(body.records_to_include)
    .toArray();

  if (!completedRecords.length) {
    throw new HTTPException(404, { message: "No completed records found" });
  }

  // Build a simple text-based report (no reportlab in TS — can be enhanced with pdfkit later)
  const latest = completedRecords[0];
  const lines: string[] = [];

  lines.push("HealthWallet - Patient Summary");
  lines.push(`Generated: ${new Date().toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })}`);
  lines.push(`Patient: ${user.full_name ?? "Not specified"}`);
  const age = calculateAge(user.date_of_birth);
  if (age) lines.push(`Age: ${age}`);
  lines.push("");

  if (latest.summary) {
    lines.push("Executive Summary");
    lines.push(latest.summary);
    lines.push("");
  }

  if (body.include_correlations && latest.correlations?.length) {
    lines.push("Key Clinical Findings");
    for (const corr of latest.correlations) {
      lines.push(`  ${corr.condition ?? ""}: ${corr.insight ?? ""}`);
    }
    lines.push("");
  }

  const abnormal = latest.biomarkers.filter(b => b.status !== "optimal");
  if (abnormal.length) {
    lines.push("Abnormal Biomarkers");
    lines.push("  Biomarker | Value | Status | Reference Range");
    for (const b of abnormal) {
      const ref = b.reference_range;
      const refStr = ref ? `${ref.min}-${ref.max}` : "N/A";
      lines.push(`  ${b.name} | ${b.value} ${b.unit} | ${(b.status ?? "").toUpperCase()} | ${refStr}`);
    }
    lines.push("");
  }

  lines.push("Note: This summary is generated from user-uploaded lab reports and AI analysis. It is intended to facilitate discussion with healthcare providers and does not constitute medical advice.");

  // Return as base64-encoded text (PDF generation can be added with pdfkit)
  const textContent = lines.join("\n");
  const base64 = Buffer.from(textContent).toString("base64");

  return c.json({
    pdf_url: null,
    pdf_base64: base64,
    generated_at: new Date().toISOString(),
  });
});

// ===== List Records =====

records.get("/", zValidator("query", listRecordsQuerySchema), async (c) => {
  const user = await getCurrentUser(c);
  const pro = isPro(user);
  const { page, per_page } = c.req.valid("query");
  const db = getDb();
  const collection = db.collection<HealthRecord>("health_records");
  const skip = (page - 1) * per_page;

  const total = await collection.countDocuments({ user_id: user._id });
  const list = await collection
    .find({ user_id: user._id })
    .sort({ created_at: -1 })
    .skip(skip)
    .limit(per_page)
    .toArray();

  return c.json({
    records: list.map((record) => recordToResponse(record, { isPro: pro })),
    total,
    page,
    per_page,
  });
});

// ===== Verify Record =====

records.post("/:record_id/verify", zValidator("json", verifyRecordRequestSchema), async (c) => {
  const user = await getCurrentUser(c);
  const recordId = c.req.param("record_id");
  const body = c.req.valid("json");
  const db = getDb();
  const collection = db.collection<HealthRecord>("health_records");

  let oid: ObjectId;
  try {
    oid = new ObjectId(recordId);
  } catch {
    throw new HTTPException(404, { message: "Health record not found" });
  }

  const record = await collection.findOne({ _id: oid });
  if (!record) {
    throw new HTTPException(404, { message: "Health record not found" });
  }

  if (!record.user_id.equals(user._id)) {
    throw new HTTPException(403, { message: "Access denied" });
  }

  if (record.status !== RecordStatus.PENDING_REVIEW) {
    throw new HTTPException(400, { message: "Record is not pending review" });
  }

  // Apply edits
  const editMap = new Map(body.biomarker_edits.map(e => [e.name, e]));
  const editedBiomarkers = record.biomarkers.map(biomarker => {
    const name = biomarker.name ?? "";
    const edit = editMap.get(name);
    if (edit) {
      if (biomarker.value !== edit.value) {
        biomarker.original_value = biomarker.value;
        biomarker.value = edit.value;
      }
      if (edit.unit) biomarker.unit = edit.unit;
      biomarker.verified = true;
    }
    return biomarker;
  });

  let newStatus: RecordStatus;
  let errorMessage: string | null = null;
  let updatedCorrelations = record.correlations;
  let updatedSupplements = record.supplement_protocol;
  let updatedWellnessScore = record.wellness_score;
  let updatedHealthAge = record.health_age;

  if (body.approved) {
    updatedCorrelations = detectCorrelations(editedBiomarkers);
    updatedSupplements = getSupplementProtocol(editedBiomarkers);
    updatedWellnessScore = calculateWellnessScore(editedBiomarkers);
    const userAge = calculateAge(user.date_of_birth);
    if (userAge) updatedHealthAge = calculateHealthAge(editedBiomarkers, userAge);
    newStatus = RecordStatus.COMPLETED;
  } else {
    newStatus = RecordStatus.FAILED;
    errorMessage = "User rejected extracted data";
  }

  await collection.updateOne(
    { _id: oid },
    {
      $set: {
        biomarkers: editedBiomarkers,
        correlations: updatedCorrelations,
        supplement_protocol: updatedSupplements,
        wellness_score: updatedWellnessScore,
        health_age: updatedHealthAge,
        status: newStatus,
        error_message: errorMessage,
        updated_at: new Date(),
      },
    }
  );

  return c.json({
    id: recordId,
    status: newStatus,
    biomarkers: editedBiomarkers,
    message: body.approved ? "Record verified and saved." : "Record rejected.",
  });
});

// ===== Get Single Record =====

records.get("/:record_id", async (c) => {
  const user = await getCurrentUser(c);
  const pro = isPro(user);
  const recordId = c.req.param("record_id");
  const db = getDb();
  const collection = db.collection<HealthRecord>("health_records");

  let oid: ObjectId;
  try {
    oid = new ObjectId(recordId);
  } catch {
    throw new HTTPException(404, { message: "Health record not found" });
  }

  const record = await collection.findOne({ _id: oid });
  if (!record) {
    throw new HTTPException(404, { message: "Health record not found" });
  }

  if (!record.user_id.equals(user._id)) {
    throw new HTTPException(403, { message: "Access denied" });
  }

  return c.json(recordToResponse(record, { isPro: pro }));
});

export default records;

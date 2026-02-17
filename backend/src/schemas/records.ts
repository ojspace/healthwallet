import { z } from "zod";

// ===== Upload & Basic Record Responses =====

export const uploadResponseSchema = z.object({
  record_id: z.string(),
  status: z.string(),
  message: z.string().default("File uploaded successfully. Processing started."),
});

export const biomarkerResponseSchema = z.object({
  name: z.string(),
  value: z.number(),
  unit: z.string(),
  reference_range: z.object({ min: z.number(), max: z.number() }).nullable().optional(),
  status: z.string().nullable().optional(),
  category: z.string().nullable().optional(),
  confidence: z.number().nullable().optional(),
  verified: z.boolean().default(false),
});

export const healthRecordResponseSchema = z.object({
  id: z.string(),
  status: z.string(),
  original_filename: z.string(),
  record_date: z.string().nullable(),
  lab_provider: z.string().nullable(),
  record_type: z.string().default("blood_panel"),
  biomarkers: z.array(z.record(z.any())),
  summary: z.string().nullable(),
  correlations: z.array(z.record(z.any())),
  key_findings: z.array(z.string()),
  recommendations: z.array(z.string()),
  food_recommendations: z.array(z.record(z.any())),
  supplement_protocol: z.array(z.record(z.any())),
  wellness_score: z.number().nullable(),
  health_age: z.number().nullable(),
  error_message: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export const healthRecordListResponseSchema = z.object({
  records: z.array(healthRecordResponseSchema),
  total: z.number(),
  page: z.number(),
  per_page: z.number(),
});

// ===== Epic 1: Verification =====

export const biomarkerEditSchema = z.object({
  name: z.string(),
  value: z.number(),
  unit: z.string().nullable().optional(),
  verified: z.boolean().default(true),
});

export const verifyRecordRequestSchema = z.object({
  biomarker_edits: z.array(biomarkerEditSchema),
  approved: z.boolean().default(true),
});

export const verifyRecordResponseSchema = z.object({
  id: z.string(),
  status: z.string(),
  biomarkers: z.array(z.record(z.any())),
  message: z.string(),
});

// ===== Epic 4: Comparison =====

export const biomarkerTrendSchema = z.object({
  name: z.string(),
  unit: z.string(),
  data_points: z.array(z.record(z.any())),
  change_percent: z.number().nullable(),
  trend: z.string().default("stable"),
});

export const comparisonResponseSchema = z.object({
  biomarker_trends: z.array(biomarkerTrendSchema),
  records_compared: z.number(),
  date_range: z.object({ start: z.string(), end: z.string() }),
});

// ===== Dashboard =====

export const dashboardResponseSchema = z.object({
  wellness_score: z.number(),
  health_age: z.number().nullable(),
  chronological_age: z.number().nullable(),
  last_sync: z.string(),
  summary: z.string().nullable(),
  score_breakdown: z.record(z.number()),
  biomarker_trends: z.array(z.record(z.any())),
  key_findings: z.array(z.string()),
  correlations: z.array(z.record(z.any())),
  action_plan: z.array(z.record(z.any())),
  supplement_protocol: z.array(z.record(z.any())),
  total_records: z.number(),
});

// ===== Doctor Brief =====

export const doctorBriefRequestSchema = z.object({
  include_trends: z.boolean().default(true),
  include_correlations: z.boolean().default(true),
  records_to_include: z.number().default(3),
});

export const doctorBriefResponseSchema = z.object({
  pdf_url: z.string().nullable().optional(),
  pdf_base64: z.string().nullable().optional(),
  generated_at: z.string(),
});

// ===== Query schemas =====

export const listRecordsQuerySchema = z.object({
  page: z.coerce.number().min(1).default(1),
  per_page: z.coerce.number().min(1).max(100).default(10),
});

// Type exports
export type UploadResponse = z.infer<typeof uploadResponseSchema>;
export type HealthRecordResponse = z.infer<typeof healthRecordResponseSchema>;
export type HealthRecordListResponse = z.infer<typeof healthRecordListResponseSchema>;
export type VerifyRecordRequest = z.infer<typeof verifyRecordRequestSchema>;
export type VerifyRecordResponse = z.infer<typeof verifyRecordResponseSchema>;
export type DashboardResponse = z.infer<typeof dashboardResponseSchema>;
export type ComparisonResponse = z.infer<typeof comparisonResponseSchema>;
export type DoctorBriefRequest = z.infer<typeof doctorBriefRequestSchema>;

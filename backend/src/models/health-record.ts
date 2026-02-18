import { ObjectId } from "mongodb";

export const RecordStatus = {
  UPLOADING: "uploading",
  PROCESSING: "processing",
  PENDING_REVIEW: "pending_review",
  COMPLETED: "completed",
  FAILED: "failed",
} as const;

export type RecordStatus = (typeof RecordStatus)[keyof typeof RecordStatus];

export interface BiomarkerData {
  name: string;
  value: number;
  unit: string;
  reference_range?: { min: number; max: number } | null;
  status?: string | null; // "optimal", "low", "high"
  category?: string | null;
  verified?: boolean;
  original_value?: number | null;
  confidence?: number | null;
}

export interface Correlation {
  markers: string[];
  insight: string;
  severity: string; // "info", "warning", "critical"
  condition?: string | null;
}

export interface SupplementRecommendation {
  name: string;
  dosage: string;
  reason: string;
  biomarker_link: string;
  priority: string; // "essential", "recommended", "optional"
}

export interface HealthRecord {
  _id: ObjectId;
  user_id: ObjectId;
  file_url: string;
  original_filename: string;
  status: RecordStatus;

  // Record metadata
  record_date: Date | null;
  lab_provider: string | null;
  record_type: string;

  // Encrypted raw text
  raw_text_encrypted: string | null; // base64 encoded

  // Parsed data
  parsed_data: Record<string, any> | null;
  biomarkers: Record<string, any>[];

  // AI Analysis
  summary: string | null;
  correlations: Record<string, any>[];
  key_findings: string[];

  // Recommendations
  recommendations: string[];
  food_recommendations: Record<string, any>[];
  supplement_protocol: Record<string, any>[];

  // Health metrics
  wellness_score: number | null;
  health_age: number | null;

  // Error
  error_message: string | null;

  // Timestamps
  created_at: Date;
  updated_at: Date;
}

export function createDefaultRecord(
  partial: Pick<HealthRecord, "user_id" | "file_url" | "original_filename"> & Partial<HealthRecord>
): Omit<HealthRecord, "_id"> {
  return {
    user_id: partial.user_id,
    file_url: partial.file_url,
    original_filename: partial.original_filename,
    status: partial.status ?? RecordStatus.UPLOADING,
    record_date: partial.record_date ?? null,
    lab_provider: partial.lab_provider ?? null,
    record_type: partial.record_type ?? "blood_panel",
    raw_text_encrypted: null,
    parsed_data: null,
    biomarkers: [],
    summary: null,
    correlations: [],
    key_findings: [],
    recommendations: [],
    food_recommendations: [],
    supplement_protocol: [],
    wellness_score: null,
    health_age: null,
    error_message: null,
    created_at: new Date(),
    updated_at: new Date(),
  };
}

export function calculateWellnessScore(biomarkers: Record<string, any>[]): number {
  if (!biomarkers.length) return 0;

  let optimalCount = 0;
  let totalCount = 0;

  for (const biomarker of biomarkers) {
    const status = (biomarker.status ?? "optimal").toLowerCase();
    totalCount++;
    if (status === "optimal" || status === "normal") {
      optimalCount++;
    }
  }

  // Score is percentage of optimal markers, scaled to 30-100 range
  // Even with all bad markers you get a baseline 30 (you're alive!)
  const ratio = totalCount > 0 ? optimalCount / totalCount : 0;
  return Math.round(30 + ratio * 70);
}

export function calculateHealthAge(
  biomarkers: Record<string, any>[],
  chronologicalAge: number
): number | null {
  if (!biomarkers.length) return null;

  const markers: Record<string, number> = {};
  for (const b of biomarkers) {
    const name = (b.name ?? "").toLowerCase();
    if (b.value != null) markers[name] = b.value;
  }

  let ageModifier = 0;

  // Glucose
  const glucose = markers["fasting glucose"] ?? markers["glucose"];
  if (glucose != null) {
    if (glucose > 100) ageModifier += 2;
    else if (glucose < 70) ageModifier += 1;
  }

  // LDL
  const ldl = markers["ldl"] ?? markers["ldl cholesterol"];
  if (ldl != null) {
    if (ldl > 160) ageModifier += 3;
    else if (ldl > 130) ageModifier += 1;
    else if (ldl < 100) ageModifier -= 1;
  }

  // HDL
  const hdl = markers["hdl"] ?? markers["hdl cholesterol"];
  if (hdl != null) {
    if (hdl > 60) ageModifier -= 2;
    else if (hdl < 40) ageModifier += 2;
  }

  // Vitamin D
  const vitD = markers["vitamin d"] ?? markers["25-hydroxy vitamin d"];
  if (vitD != null) {
    if (vitD >= 40 && vitD <= 60) ageModifier -= 1;
    else if (vitD < 20) ageModifier += 2;
  }

  // HbA1c
  const hba1c = markers["hba1c"] ?? markers["hemoglobin a1c"];
  if (hba1c != null) {
    if (hba1c < 5.5) ageModifier -= 1;
    else if (hba1c > 6.0) ageModifier += 3;
  }

  return chronologicalAge + ageModifier;
}

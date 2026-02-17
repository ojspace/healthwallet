import { z } from "zod";

export const dailyMetricSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  steps: z.number().min(0).default(0),
  active_energy_kcal: z.number().min(0).default(0),
  sleep_hours: z.number().min(0).max(24).default(0),
  sleep_deep_hours: z.number().min(0).max(24).optional(),
  sleep_rem_hours: z.number().min(0).max(24).optional(),
  heart_rate_avg: z.number().min(0).optional(),
  heart_rate_min: z.number().min(0).optional(),
  heart_rate_max: z.number().min(0).optional(),
  resting_heart_rate: z.number().min(0).optional(),
  hrv_avg: z.number().min(0).optional(),
  weight_kg: z.number().min(0).optional(),
});

export const syncHealthKitSchema = z.object({
  metrics: z.array(dailyMetricSchema).min(1).max(90),
});

export const summaryQuerySchema = z.object({
  days: z.coerce.number().min(1).max(365).default(30),
});

import { z } from "zod";

export const churnkeyWebhookSchema = z.object({
  event: z.enum([
    "cancellation.started",
    "cancellation.completed",
    "cancellation.deflected",
    "cancellation.paused",
  ]),
  customer: z.object({
    id: z.string(),
    email: z.string().optional(),
  }),
  reason: z.object({
    category: z.enum(["price", "usage", "competition", "features", "technical", "temporary", "other"]).optional(),
    text: z.string().optional(),
  }).optional(),
  offer: z.object({
    shown: z.string().optional(),
    accepted: z.boolean().optional(),
    type: z.string().optional(),
  }).optional(),
  feedback: z.string().optional(),
  pause_duration_days: z.number().optional(),
  timestamp: z.string().optional(),
});

export const churnSummaryQuerySchema = z.object({
  period: z.enum(["day", "week", "month"]).default("week"),
  days: z.coerce.number().min(1).max(365).default(30),
});

export type ChurnkeyWebhook = z.infer<typeof churnkeyWebhookSchema>;
export type ChurnSummaryQuery = z.infer<typeof churnSummaryQuerySchema>;

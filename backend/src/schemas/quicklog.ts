import { z } from "zod";

export const quickLogSchema = z.object({
  mood: z.number().min(1).max(5),
  energy: z.number().min(1).max(5),
  symptoms: z.array(z.string()).max(10).default([]),
  notes: z.string().max(500).optional(),
});

export const logQuerySchema = z.object({
  days: z.coerce.number().min(1).max(365).default(30),
});

export const calendarQuerySchema = z.object({
  month: z.string().regex(/^\d{4}-\d{2}$/),
});

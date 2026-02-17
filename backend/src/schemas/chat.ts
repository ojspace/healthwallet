import { z } from "zod";

export const sendMessageSchema = z.object({
  message: z.string().min(1).max(2000),
});

export const chatHistoryQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(50),
  before: z.string().optional(), // cursor: message ID
});

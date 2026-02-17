import { z } from "zod";

export const appleAuthSchema = z.object({
  identity_token: z.string().min(1),
  full_name: z.string().optional(),
  nonce: z.string().optional(),
});

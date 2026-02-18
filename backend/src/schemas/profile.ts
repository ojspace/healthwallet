import { z } from "zod";

export const updateProfileSchema = z.object({
  full_name: z.string().min(1).max(100).optional(),
  date_of_birth: z.string().optional(),
  gender: z.enum(["male", "female", "other"]).optional(),
  biological_sex: z.enum(["male", "female", "other"]).optional(),
  dietary_preference: z.enum(["omnivore", "vegetarian", "vegan", "keto", "paleo", "pescatarian"]).optional(),
  allergies: z.array(z.string()).optional(),
  health_goals: z.array(z.string()).optional(),
  health_conditions: z.array(z.string()).optional(),
});

export const completeOnboardingSchema = z.object({
  full_name: z.string().min(1).max(100).optional().nullable(),
  date_of_birth: z.string().optional().nullable(),
  gender: z.enum(["male", "female", "other"]).optional().nullable(),
  biological_sex: z.enum(["male", "female", "other"]).optional().nullable(),
  dietary_preference: z.enum(["omnivore", "vegetarian", "vegan", "keto", "paleo", "pescatarian"]).optional(),
  allergies: z.array(z.string()).optional(),
  health_goals: z.array(z.string()).optional(),
  health_conditions: z.array(z.string()).optional(),
});

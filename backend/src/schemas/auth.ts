import { z } from "zod";

export const userCreateSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  full_name: z.string().nullable().optional(),
});

export const userLoginSchema = z.object({
  username: z.string().email(), // OAuth2 form uses "username" field
  password: z.string(),
});

export const userProfileUpdateSchema = z.object({
  full_name: z.string().nullable().optional(),
  date_of_birth: z.string().datetime().nullable().optional(),
  dietary_preference: z.enum(["omnivore", "vegetarian", "vegan", "keto", "paleo", "pescatarian"]).optional(),
  allergies: z.array(z.string()).optional(),
  health_goals: z.array(z.string()).optional(),
});

export const onboardingCompleteSchema = z.object({
  full_name: z.string().nullable().optional(),
  date_of_birth: z.string().datetime().nullable().optional(),
  biological_sex: z.enum(["male", "female", "other"]).nullable().optional(),
  dietary_preference: z.enum(["omnivore", "vegetarian", "vegan", "keto", "paleo", "pescatarian"]),
  allergies: z.array(z.string()).default([]),
  health_goals: z.array(z.string()).default([]),
  health_conditions: z.array(z.string()).default([]),
});

export const userResponseSchema = z.object({
  id: z.string(),
  email: z.string(),
  full_name: z.string().nullable(),
  is_active: z.boolean(),
  date_of_birth: z.string().nullable(),
  dietary_preference: z.string(),
  allergies: z.array(z.string()),
  health_goals: z.array(z.string()),
  onboarding_completed: z.boolean(),
  age: z.number().nullable(),
  subscription_tier: z.enum(["free", "pro"]),
  subscription_expires_at: z.string().nullable(),
  upload_count: z.number(),
  can_upload: z.boolean(),
});

export const tokenSchema = z.object({
  access_token: z.string(),
  token_type: z.string().default("bearer"),
});

export type UserCreate = z.infer<typeof userCreateSchema>;
export type UserLogin = z.infer<typeof userLoginSchema>;
export type UserProfileUpdate = z.infer<typeof userProfileUpdateSchema>;
export type OnboardingComplete = z.infer<typeof onboardingCompleteSchema>;
export type UserResponse = z.infer<typeof userResponseSchema>;
export type Token = z.infer<typeof tokenSchema>;

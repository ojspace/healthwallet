import { ObjectId } from "mongodb";

export const SubscriptionTier = {
  FREE: "free",
  PRO: "pro",
} as const;

export type SubscriptionTier = (typeof SubscriptionTier)[keyof typeof SubscriptionTier];

export const DietaryPreference = {
  OMNIVORE: "omnivore",
  VEGETARIAN: "vegetarian",
  VEGAN: "vegan",
  KETO: "keto",
  PALEO: "paleo",
  PESCATARIAN: "pescatarian",
} as const;

export type DietaryPreference = (typeof DietaryPreference)[keyof typeof DietaryPreference];

export interface User {
  _id: ObjectId;
  email: string;
  hashed_password: string;
  full_name: string | null;
  is_active: boolean;

  // Profile & Preferences
  date_of_birth: Date | null;
  gender: "male" | "female" | "other" | null;
  dietary_preference: DietaryPreference;
  allergies: string[];
  health_goals: string[];
  health_conditions: string[];

  // Onboarding
  onboarding_completed: boolean;

  // Subscription
  subscription_tier: SubscriptionTier;
  subscription_expires_at: Date | null;
  revenuecat_id: string | null;
  upload_count: number;

  // Apple Sign-In
  apple_id: string | null;
  auth_provider: "email" | "apple";

  // Telegram
  telegram_id: number | null;
  telegram_linked_at: Date | null;

  // Timestamps
  created_at: Date;
  updated_at: Date;
}

export function calculateAge(dateOfBirth: Date | null): number | null {
  if (!dateOfBirth) return null;
  const today = new Date();
  let age = today.getFullYear() - dateOfBirth.getFullYear();
  const monthDiff = today.getMonth() - dateOfBirth.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < dateOfBirth.getDate())) {
    age--;
  }
  return age;
}

export function createDefaultUser(partial: Partial<User> & { email: string; hashed_password: string }): Omit<User, "_id"> {
  return {
    email: partial.email,
    hashed_password: partial.hashed_password,
    full_name: partial.full_name ?? null,
    is_active: true,
    date_of_birth: partial.date_of_birth ?? null,
    gender: partial.gender ?? null,
    dietary_preference: partial.dietary_preference ?? DietaryPreference.OMNIVORE,
    allergies: partial.allergies ?? [],
    health_goals: partial.health_goals ?? [],
    health_conditions: partial.health_conditions ?? [],
    onboarding_completed: false,
    subscription_tier: partial.subscription_tier ?? SubscriptionTier.FREE,
    subscription_expires_at: partial.subscription_expires_at ?? null,
    revenuecat_id: partial.revenuecat_id ?? null,
    upload_count: partial.upload_count ?? 0,
    apple_id: partial.apple_id ?? null,
    auth_provider: partial.auth_provider ?? "email",
    telegram_id: partial.telegram_id ?? null,
    telegram_linked_at: partial.telegram_linked_at ?? null,
    created_at: new Date(),
    updated_at: new Date(),
  };
}

import { calculateAge, SubscriptionTier } from "../models/user.js";
import type { User } from "../models/user.js";
import { isPro, FREE_UPLOAD_LIMIT } from "./subscription.js";

export function userToResponse(user: User) {
  const pro = isPro(user);
  return {
    id: user._id.toHexString(),
    email: user.email,
    full_name: user.full_name,
    is_active: user.is_active,
    date_of_birth: user.date_of_birth?.toISOString() ?? null,
    biological_sex: user.gender ?? null,
    dietary_preference: user.dietary_preference,
    allergies: user.allergies,
    health_goals: user.health_goals,
    health_conditions: user.health_conditions ?? [],
    onboarding_completed: user.onboarding_completed,
    age: calculateAge(user.date_of_birth),
    subscription_tier: pro ? SubscriptionTier.PRO : SubscriptionTier.FREE,
    subscription_expires_at: user.subscription_expires_at?.toISOString() ?? null,
    upload_count: user.upload_count ?? 0,
    can_upload: pro || (user.upload_count ?? 0) < FREE_UPLOAD_LIMIT,
  };
}

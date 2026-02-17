import { SubscriptionTier } from "../models/user.js";
import type { User } from "../models/user.js";

export const FREE_UPLOAD_LIMIT = 1;

export function isPro(user: Pick<User, "subscription_tier" | "subscription_expires_at">): boolean {
  if (user.subscription_tier !== SubscriptionTier.PRO) return false;
  if (user.subscription_expires_at && user.subscription_expires_at < new Date()) return false;
  return true;
}

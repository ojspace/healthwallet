import type { ChurnReasonCategory } from "../models/churn-event.js";

export interface RetentionOffer {
  type: "discount" | "pause" | "downgrade" | "extension";
  title: string;
  description: string;
  details: {
    discount_percent?: number;
    duration_months?: number;
    pause_months?: number;
    extension_days?: number;
  };
}

// Reason → best offer mapping
const OFFER_MAP: Record<string, RetentionOffer> = {
  price: {
    type: "discount",
    title: "50% Off for 3 Months",
    description: "We'd love to keep you! Enjoy Health Wallet Pro at $3.49/mo for the next 3 months.",
    details: { discount_percent: 50, duration_months: 3 },
  },
  usage: {
    type: "extension",
    title: "30 Days Free",
    description: "Give us another chance! Here's 30 extra days to explore all Pro features.",
    details: { extension_days: 30 },
  },
  temporary: {
    type: "pause",
    title: "Pause Your Subscription",
    description: "No worries! Pause your subscription for up to 3 months. We'll be here when you're ready.",
    details: { pause_months: 3 },
  },
  features: {
    type: "extension",
    title: "30 Days Free + Feature Request",
    description: "Tell us what you need! Get 30 free days while we work on improvements.",
    details: { extension_days: 30 },
  },
  competition: {
    type: "discount",
    title: "30% Off for 6 Months",
    description: "Stay with us at a lower price. 30% off for the next 6 months.",
    details: { discount_percent: 30, duration_months: 6 },
  },
  technical: {
    type: "extension",
    title: "30 Days Free While We Fix It",
    description: "We're sorry for the trouble. Here's 30 free days while our team addresses the issue.",
    details: { extension_days: 30 },
  },
  other: {
    type: "discount",
    title: "25% Off for 3 Months",
    description: "We'd hate to see you go. How about 25% off for the next 3 months?",
    details: { discount_percent: 25, duration_months: 3 },
  },
};

/**
 * Select the best retention offer based on cancellation reason.
 * Checks if user has received an offer recently (90-day cooldown).
 */
export function selectOffer(
  reasonCategory: ChurnReasonCategory | string | null,
  previousOffers: { type: string; created_at: Date }[]
): RetentionOffer | null {
  const category = reasonCategory ?? "other";
  const offer = OFFER_MAP[category] ?? OFFER_MAP["other"];

  // Check 90-day cooldown for same offer type
  const ninety = 90 * 24 * 60 * 60 * 1000;
  const recentSameType = previousOffers.find(
    (prev) => prev.type === offer.type && Date.now() - prev.created_at.getTime() < ninety
  );

  if (recentSameType) {
    // Fall back to a different offer type
    const fallbacks = Object.values(OFFER_MAP).filter((o) => o.type !== offer.type);
    const fallback = fallbacks.find(
      (fb) =>
        !previousOffers.some(
          (prev) => prev.type === fb.type && Date.now() - prev.created_at.getTime() < ninety
        )
    );
    return fallback ?? null; // No valid offers available
  }

  return offer;
}

/**
 * Get all available offer configurations (for admin)
 */
export function getOfferConfigs(): Record<string, RetentionOffer> {
  return { ...OFFER_MAP };
}

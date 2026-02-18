import { ObjectId } from "mongodb";

export const ChurnEventType = {
  CANCELLATION_STARTED: "cancellation.started",
  CANCELLATION_COMPLETED: "cancellation.completed",
  CANCELLATION_DEFLECTED: "cancellation.deflected",
  CANCELLATION_PAUSED: "cancellation.paused",
} as const;

export type ChurnEventType = (typeof ChurnEventType)[keyof typeof ChurnEventType];

export const ChurnReasonCategory = {
  PRICE: "price",
  USAGE: "usage",
  COMPETITION: "competition",
  FEATURES: "features",
  TECHNICAL: "technical",
  TEMPORARY: "temporary",
  OTHER: "other",
} as const;

export type ChurnReasonCategory = (typeof ChurnReasonCategory)[keyof typeof ChurnReasonCategory];

export interface ChurnEvent {
  _id: ObjectId;
  user_id: ObjectId;
  event_type: ChurnEventType;
  reason_category: ChurnReasonCategory | null;
  reason_text: string | null;
  offer_shown: string | null;
  offer_accepted: boolean;
  offer_type: string | null;
  feedback_text: string | null;
  pause_duration_days: number | null;
  created_at: Date;
}

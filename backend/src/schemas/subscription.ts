import { z } from "zod";

// RevenueCat webhook event types we handle
export const revenuecatWebhookSchema = z.object({
  api_version: z.string().optional(),
  event: z.object({
    type: z.enum([
      "INITIAL_PURCHASE",
      "RENEWAL",
      "CANCELLATION",
      "EXPIRATION",
      "PRODUCT_CHANGE",
      "BILLING_ISSUE",
      "SUBSCRIBER_ALIAS",
      "SUBSCRIPTION_PAUSED",
      "TRANSFER",
      "NON_RENEWING_PURCHASE",
      "SUBSCRIPTION_EXTENDED",
      "TEST",
    ]),
    app_user_id: z.string(),
    original_app_user_id: z.string().optional(),
    product_id: z.string().optional(),
    entitlement_ids: z.array(z.string()).optional(),
    expiration_at_ms: z.number().nullable().optional(),
    purchased_at_ms: z.number().nullable().optional(),
    store: z.string().optional(),
    environment: z.string().optional(),
    is_trial_conversion: z.boolean().optional(),
    cancel_reason: z.string().optional(),
  }),
});

export const verifyReceiptSchema = z.object({
  revenuecat_id: z.string(),
  receipt_data: z.string().optional(),
});

export type RevenueCatWebhook = z.infer<typeof revenuecatWebhookSchema>;
export type VerifyReceipt = z.infer<typeof verifyReceiptSchema>;

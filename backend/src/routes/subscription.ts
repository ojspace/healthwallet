import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";
import { HTTPException } from "hono/http-exception";
import { getDb } from "../db.js";
import { config } from "../config.js";
import { getCurrentUser } from "../middleware/auth.js";
import { SubscriptionTier } from "../models/user.js";
import type { User } from "../models/user.js";
import { revenuecatWebhookSchema, verifyReceiptSchema } from "../schemas/subscription.js";
import { createHmac } from "crypto";

const subscription = new Hono();

// ===== POST /webhooks/revenuecat =====
// Receives RevenueCat server-to-server events

subscription.post("/webhooks/revenuecat", async (c) => {
  // Validate webhook signature if secret is configured
  if (config.revenuecatWebhookSecret) {
    const signature = c.req.header("X-RevenueCat-Signature") ?? "";
    const body = await c.req.text();

    const expectedSig = createHmac("sha256", config.revenuecatWebhookSecret)
      .update(body)
      .digest("hex");

    if (signature !== expectedSig) {
      console.warn("[Webhook] Invalid RevenueCat signature");
      throw new HTTPException(401, { message: "Invalid webhook signature" });
    }

    // Re-parse the body since we consumed it
    const parsed = revenuecatWebhookSchema.safeParse(JSON.parse(body));
    if (!parsed.success) {
      throw new HTTPException(400, { message: "Invalid webhook payload" });
    }

    return handleWebhookEvent(c, parsed.data);
  }

  // No secret configured — parse body normally (dev mode)
  const parsed = revenuecatWebhookSchema.safeParse(await c.req.json());
  if (!parsed.success) {
    throw new HTTPException(400, { message: "Invalid webhook payload" });
  }

  return handleWebhookEvent(c, parsed.data);
});

async function handleWebhookEvent(c: any, webhook: any) {
  const event = webhook.event;
  const appUserId = event.app_user_id;

  console.log(`[Webhook] RevenueCat event: ${event.type} for user ${appUserId}`);

  const db = getDb();
  const users = db.collection<User>("users");

  // Find user by revenuecat_id or by _id (app_user_id = our user id)
  const user = await users.findOne({
    $or: [
      { revenuecat_id: appUserId },
      ...(appUserId.match(/^[0-9a-f]{24}$/) ? [{ _id: new (await import("mongodb")).ObjectId(appUserId) }] : []),
    ],
  });

  if (!user) {
    console.warn(`[Webhook] User not found for app_user_id: ${appUserId}`);
    // Return 200 to prevent RevenueCat from retrying
    return c.json({ status: "user_not_found" });
  }

  const hasPro = event.entitlement_ids?.includes("pro") ?? false;
  const expiresAt = event.expiration_at_ms ? new Date(event.expiration_at_ms) : null;

  switch (event.type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "SUBSCRIPTION_EXTENDED":
    case "NON_RENEWING_PURCHASE": {
      await users.updateOne(
        { _id: user._id },
        {
          $set: {
            subscription_tier: hasPro ? SubscriptionTier.PRO : SubscriptionTier.FREE,
            subscription_expires_at: expiresAt,
            revenuecat_id: appUserId,
            updated_at: new Date(),
          },
        }
      );
      console.log(`[Webhook] User ${user._id} upgraded to PRO (expires: ${expiresAt})`);
      break;
    }

    case "CANCELLATION":
    case "EXPIRATION": {
      await users.updateOne(
        { _id: user._id },
        {
          $set: {
            subscription_tier: SubscriptionTier.FREE,
            subscription_expires_at: expiresAt,
            updated_at: new Date(),
          },
        }
      );
      console.log(`[Webhook] User ${user._id} downgraded to FREE`);
      break;
    }

    case "BILLING_ISSUE": {
      console.warn(`[Webhook] Billing issue for user ${user._id}`);
      break;
    }

    case "SUBSCRIPTION_PAUSED": {
      await users.updateOne(
        { _id: user._id },
        {
          $set: {
            subscription_tier: SubscriptionTier.FREE,
            updated_at: new Date(),
          },
        }
      );
      console.log(`[Webhook] User ${user._id} subscription paused`);
      break;
    }

    case "TEST": {
      console.log("[Webhook] Test event received");
      break;
    }

    default:
      console.log(`[Webhook] Unhandled event type: ${event.type}`);
  }

  return c.json({ status: "ok" });
}

// ===== POST /auth/verify-receipt =====
// Client sends RevenueCat user ID to link accounts

subscription.post("/verify-receipt", async (c) => {
  const user = await getCurrentUser(c);
  const body = await c.req.json();
  const parsed = verifyReceiptSchema.safeParse(body);

  if (!parsed.success) {
    throw new HTTPException(400, { message: "Invalid request" });
  }

  const db = getDb();
  const users = db.collection<User>("users");

  // Link RevenueCat ID to user
  await users.updateOne(
    { _id: user._id },
    {
      $set: {
        revenuecat_id: parsed.data.revenuecat_id,
        updated_at: new Date(),
      },
    }
  );

  console.log(`[Receipt] Linked RevenueCat ID ${parsed.data.revenuecat_id} to user ${user._id}`);

  return c.json({
    status: "linked",
    revenuecat_id: parsed.data.revenuecat_id,
  });
});

// ===== GET /subscription/status =====
// Check current subscription status

subscription.get("/status", async (c) => {
  const user = await getCurrentUser(c);

  const isPro =
    user.subscription_tier === SubscriptionTier.PRO &&
    (!user.subscription_expires_at || user.subscription_expires_at >= new Date());

  return c.json({
    subscription_tier: isPro ? SubscriptionTier.PRO : SubscriptionTier.FREE,
    subscription_expires_at: user.subscription_expires_at?.toISOString() ?? null,
    revenuecat_id: user.revenuecat_id,
    upload_count: user.upload_count ?? 0,
    can_upload: isPro || (user.upload_count ?? 0) < 1,
    features: {
      unlimited_uploads: isPro,
      supplement_protocol: isPro,
      doctor_brief: isPro,
      year_comparison: isPro,
      full_food_recommendations: isPro,
    },
  });
});

export default subscription;

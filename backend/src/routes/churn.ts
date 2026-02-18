import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";
import { HTTPException } from "hono/http-exception";
import { ObjectId } from "mongodb";
import { createHmac } from "crypto";
import { getDb } from "../db.js";
import { config } from "../config.js";
import { getCurrentUser } from "../middleware/auth.js";
import { SubscriptionTier } from "../models/user.js";
import type { User } from "../models/user.js";
import type { ChurnEvent } from "../models/churn-event.js";
import { churnkeyWebhookSchema, churnSummaryQuerySchema } from "../schemas/churn.js";
import { selectOffer, getOfferConfigs } from "../services/offer-engine.js";

const churn = new Hono();

// Protect all /admin/* endpoints (JWT required + allowlisted admin email)
churn.use("/admin/*", async (c, next) => {
  const user = await getCurrentUser(c);
  const isAdmin = config.adminEmails.length > 0
    ? config.adminEmails.includes(user.email.toLowerCase())
    : config.debug; // allow in dev only if not configured

  if (!isAdmin) {
    throw new HTTPException(403, { message: "Admin access required" });
  }

  await next();
});

// ===== POST /webhooks/churnkey =====

churn.post("/webhooks/churnkey", async (c) => {
  // Validate signature if secret is configured
  if (config.churnkeyWebhookSecret) {
    const signature = c.req.header("X-Churnkey-Signature") ?? "";
    const body = await c.req.text();

    const expectedSig = createHmac("sha256", config.churnkeyWebhookSecret)
      .update(body)
      .digest("hex");

    if (signature !== expectedSig) {
      console.warn("[Churnkey] Invalid webhook signature");
      throw new HTTPException(401, { message: "Invalid webhook signature" });
    }

    const parsed = churnkeyWebhookSchema.safeParse(JSON.parse(body));
    if (!parsed.success) {
      throw new HTTPException(400, { message: "Invalid webhook payload" });
    }

    return handleChurnEvent(c, parsed.data);
  }

  // No secret — parse normally (dev mode)
  const parsed = churnkeyWebhookSchema.safeParse(await c.req.json());
  if (!parsed.success) {
    throw new HTTPException(400, { message: "Invalid webhook payload" });
  }

  return handleChurnEvent(c, parsed.data);
});

async function handleChurnEvent(c: any, webhook: any) {
  const db = getDb();
  const users = db.collection<User>("users");
  const churnEvents = db.collection<ChurnEvent>("churn_events");

  const customerId = webhook.customer.id;

  // Find user by revenuecat_id, email, or ObjectId
  const orFilters: any[] = [{ revenuecat_id: customerId }];
  if (webhook.customer.email) {
    orFilters.push({ email: webhook.customer.email });
  }
  if (customerId.match(/^[0-9a-f]{24}$/)) {
    orFilters.push({ _id: new ObjectId(customerId) });
  }

  const user = await users.findOne({ $or: orFilters });

  if (!user) {
    console.warn(`[Churnkey] User not found: ${customerId}`);
    return c.json({ status: "user_not_found" });
  }

  // Store churn event
  const event: Omit<ChurnEvent, "_id"> = {
    user_id: user._id,
    event_type: webhook.event as any,
    reason_category: webhook.reason?.category ?? null,
    reason_text: webhook.reason?.text ?? null,
    offer_shown: webhook.offer?.shown ?? null,
    offer_accepted: webhook.offer?.accepted ?? false,
    offer_type: webhook.offer?.type ?? null,
    feedback_text: webhook.feedback ?? null,
    pause_duration_days: webhook.pause_duration_days ?? null,
    created_at: webhook.timestamp ? new Date(webhook.timestamp) : new Date(),
  };

  await churnEvents.insertOne(event as any);
  console.log(`[Churnkey] Stored ${webhook.event} for user ${user._id}`);

  // Process based on event type
  switch (webhook.event) {
    case "cancellation.started":
      console.log(`[Churnkey] Cancellation started for ${user.email}`);
      break;

    case "cancellation.deflected":
      console.log(`[Churnkey] Cancellation deflected for ${user.email} (offer: ${webhook.offer?.type})`);
      break;

    case "cancellation.completed":
      await users.updateOne(
        { _id: user._id },
        {
          $set: {
            subscription_tier: SubscriptionTier.FREE,
            updated_at: new Date(),
          },
        }
      );
      console.log(`[Churnkey] Cancellation completed — ${user.email} downgraded to FREE`);
      break;

    case "cancellation.paused":
      await users.updateOne(
        { _id: user._id },
        {
          $set: {
            subscription_tier: SubscriptionTier.FREE,
            updated_at: new Date(),
          },
        }
      );
      console.log(`[Churnkey] Subscription paused for ${user.email} (${webhook.pause_duration_days} days)`);
      break;
  }

  return c.json({ status: "ok" });
}

// ===== Analytics Endpoints (admin) =====

// GET /admin/churn/summary
churn.get("/admin/churn/summary", zValidator("query", churnSummaryQuerySchema), async (c) => {
  const { days } = c.req.valid("query");
  const db = getDb();
  const churnEvents = db.collection<ChurnEvent>("churn_events");
  const users = db.collection<User>("users");

  const since = new Date();
  since.setDate(since.getDate() - days);

  const events = await churnEvents.find({ created_at: { $gte: since } }).toArray();

  const totalAttempts = events.filter(e => e.event_type === "cancellation.started").length;
  const deflected = events.filter(e => e.event_type === "cancellation.deflected").length;
  const completed = events.filter(e => e.event_type === "cancellation.completed").length;
  const paused = events.filter(e => e.event_type === "cancellation.paused").length;

  const activeSubscribers = await users.countDocuments({
    subscription_tier: SubscriptionTier.PRO,
  });

  const deflectionRate = totalAttempts > 0 ? (deflected / totalAttempts) * 100 : 0;
  const churnRate = activeSubscribers > 0 ? (completed / activeSubscribers) * 100 : 0;

  return c.json({
    period_days: days,
    cancellation_attempts: totalAttempts,
    deflected,
    completed,
    paused,
    deflection_rate: Math.round(deflectionRate * 10) / 10,
    churn_rate: Math.round(churnRate * 10) / 10,
    active_subscribers: activeSubscribers,
  });
});

// GET /admin/churn/reasons
churn.get("/admin/churn/reasons", zValidator("query", churnSummaryQuerySchema), async (c) => {
  const { days } = c.req.valid("query");
  const db = getDb();
  const churnEvents = db.collection<ChurnEvent>("churn_events");

  const since = new Date();
  since.setDate(since.getDate() - days);

  const events = await churnEvents
    .find({
      created_at: { $gte: since },
      event_type: { $in: ["cancellation.completed", "cancellation.started"] },
    })
    .toArray();

  // Group by reason category
  const reasonCounts: Record<string, number> = {};
  const feedbackTexts: string[] = [];

  for (const event of events) {
    const category = event.reason_category ?? "other";
    reasonCounts[category] = (reasonCounts[category] ?? 0) + 1;
    if (event.feedback_text) {
      feedbackTexts.push(event.feedback_text);
    }
  }

  const total = events.length;
  const reasons = Object.entries(reasonCounts)
    .map(([category, count]) => ({
      category,
      count,
      percentage: total > 0 ? Math.round((count / total) * 1000) / 10 : 0,
    }))
    .sort((a, b) => b.count - a.count);

  return c.json({
    period_days: days,
    total_events: total,
    reasons,
    recent_feedback: feedbackTexts.slice(0, 20),
  });
});

// GET /admin/churn/trends
churn.get("/admin/churn/trends", zValidator("query", churnSummaryQuerySchema), async (c) => {
  const { period, days } = c.req.valid("query");
  const db = getDb();
  const churnEvents = db.collection<ChurnEvent>("churn_events");

  const since = new Date();
  since.setDate(since.getDate() - days);

  const events = await churnEvents
    .find({ created_at: { $gte: since } })
    .sort({ created_at: 1 })
    .toArray();

  // Group by period
  const buckets: Record<string, { attempts: number; deflected: number; completed: number; paused: number }> = {};

  for (const event of events) {
    const date = event.created_at;
    let key: string;

    if (period === "day") {
      key = date.toISOString().split("T")[0];
    } else if (period === "week") {
      const weekStart = new Date(date);
      weekStart.setDate(weekStart.getDate() - weekStart.getDay());
      key = weekStart.toISOString().split("T")[0];
    } else {
      key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
    }

    if (!buckets[key]) {
      buckets[key] = { attempts: 0, deflected: 0, completed: 0, paused: 0 };
    }

    switch (event.event_type) {
      case "cancellation.started": buckets[key].attempts++; break;
      case "cancellation.deflected": buckets[key].deflected++; break;
      case "cancellation.completed": buckets[key].completed++; break;
      case "cancellation.paused": buckets[key].paused++; break;
    }
  }

  const trends = Object.entries(buckets)
    .map(([date, data]) => ({
      date,
      ...data,
      deflection_rate: data.attempts > 0
        ? Math.round((data.deflected / data.attempts) * 1000) / 10
        : 0,
    }))
    .sort((a, b) => a.date.localeCompare(b.date));

  return c.json({
    period,
    period_days: days,
    trends,
  });
});

// ===== Offer Engine =====

// GET /admin/churn/offers — List all configured offers
churn.get("/admin/churn/offers", async (c) => {
  return c.json({ offers: getOfferConfigs() });
});

// GET /admin/churn/offer/:user_id — Get best offer for a specific user
churn.get("/admin/churn/offer/:user_id", async (c) => {
  const userId = c.req.param("user_id");
  const db = getDb();
  const churnEvents = db.collection<ChurnEvent>("churn_events");

  let oid: ObjectId;
  try {
    oid = new ObjectId(userId);
  } catch {
    throw new HTTPException(400, { message: "Invalid user ID" });
  }

  // Get the user's most recent cancellation reason
  const latestEvent = await churnEvents.findOne(
    { user_id: oid, event_type: "cancellation.started" },
    { sort: { created_at: -1 } }
  );

  // Get previous offers shown to this user
  const previousOffers = await churnEvents
    .find({ user_id: oid, event_type: "cancellation.deflected" })
    .project({ offer_type: 1, created_at: 1 })
    .toArray();

  const prevOffersMapped = previousOffers.map((o) => ({
    type: o.offer_type ?? "",
    created_at: o.created_at,
  }));

  const reason = latestEvent?.reason_category ?? null;
  const offer = selectOffer(reason, prevOffersMapped);

  return c.json({
    user_id: userId,
    reason_category: reason,
    offer,
  });
});

export default churn;

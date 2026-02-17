import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";
import { HTTPException } from "hono/http-exception";
import { unlink } from "fs/promises";
import { getDb } from "../db.js";
import { hashPassword, verifyPassword } from "../services/password.js";
import { createAccessToken, getCurrentUser } from "../middleware/auth.js";
import { rateLimit } from "../middleware/rate-limit.js";
import { createDefaultUser } from "../models/user.js";
import type { User } from "../models/user.js";
import type { HealthRecord } from "../models/health-record.js";
import { userToResponse } from "../utils/user.js";
import {
  userCreateSchema,
  userLoginSchema,
  userProfileUpdateSchema,
} from "../schemas/auth.js";

const auth = new Hono();

auth.use("/register", rateLimit({ windowMs: 60_000, max: 5, keyPrefix: "auth-register" }));
auth.use("/login", rateLimit({ windowMs: 60_000, max: 10, keyPrefix: "auth-login" }));

// POST /auth/register
auth.post("/register", zValidator("json", userCreateSchema), async (c) => {
  const body = c.req.valid("json");
  const db = getDb();
  const users = db.collection<User>("users");

  const existing = await users.findOne({ email: body.email });
  if (existing) {
    throw new HTTPException(400, { message: "Email already registered" });
  }

  const hashed = await hashPassword(body.password);
  const userData = createDefaultUser({
    email: body.email,
    hashed_password: hashed,
    full_name: body.full_name ?? null,
  });

  const result = await users.insertOne(userData as any);
  const user = await users.findOne({ _id: result.insertedId });

  c.status(201);
  return c.json(userToResponse(user!));
});

// POST /auth/login (accepts both JSON and form-encoded for iOS compatibility)
auth.post("/login", async (c) => {
  let body: { username: string; password: string };
  const contentType = c.req.header("content-type") ?? "";
  if (contentType.includes("application/x-www-form-urlencoded")) {
    const formData = await c.req.parseBody();
    body = { username: String(formData.username ?? ""), password: String(formData.password ?? "") };
  } else {
    body = await c.req.json();
  }
  const parsed = userLoginSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(400, { message: "Invalid login request" });
  }
  body = parsed.data;
  const db = getDb();
  const users = db.collection<User>("users");

  const user = await users.findOne({ email: body.username });
  if (!user) {
    throw new HTTPException(401, { message: "Incorrect email or password" });
  }

  const valid = await verifyPassword(body.password, user.hashed_password);
  if (!valid) {
    throw new HTTPException(401, { message: "Incorrect email or password" });
  }

  if (!user.is_active) {
    throw new HTTPException(403, { message: "User account is deactivated" });
  }

  const accessToken = await createAccessToken(user._id.toHexString());
  return c.json({ access_token: accessToken, token_type: "bearer" });
});

// GET /auth/me
auth.get("/me", async (c) => {
  const user = await getCurrentUser(c);
  return c.json(userToResponse(user));
});

// PATCH /auth/me
auth.patch("/me", zValidator("json", userProfileUpdateSchema), async (c) => {
  const user = await getCurrentUser(c);
  const body = c.req.valid("json");
  const db = getDb();
  const users = db.collection<User>("users");

  const updateFields: Record<string, any> = { updated_at: new Date() };

  if (body.full_name !== undefined) updateFields.full_name = body.full_name;
  if (body.date_of_birth !== undefined) {
    updateFields.date_of_birth = body.date_of_birth ? new Date(body.date_of_birth) : null;
  }
  if (body.dietary_preference !== undefined) updateFields.dietary_preference = body.dietary_preference;
  if (body.allergies !== undefined) updateFields.allergies = body.allergies;
  if (body.health_goals !== undefined) updateFields.health_goals = body.health_goals;

  await users.updateOne({ _id: user._id }, { $set: updateFields });
  const updated = await users.findOne({ _id: user._id });

  return c.json(userToResponse(updated!));
});

// DELETE /auth/account — permanently delete account + all user data (Apple 5.1.1)
auth.delete("/account", async (c) => {
  const user = await getCurrentUser(c);
  const db = getDb();

  const userIdStr = user._id.toString();

  const users = db.collection<User>("users");
  const healthRecords = db.collection<HealthRecord>("health_records");

  // 1) Delete uploaded files first (avoid orphaned PHI on disk)
  const records = await healthRecords
    .find({ user_id: user._id }, { projection: { file_url: 1 } })
    .toArray();

  for (const record of records) {
    if (!record.file_url) continue;
    try {
      await unlink(record.file_url);
    } catch (err: any) {
      // If file is already gone, continue; otherwise abort deletion.
      if (err?.code !== "ENOENT") {
        console.error("[Account Deletion] Failed to delete file:", record.file_url, err);
        throw new HTTPException(500, { message: "Failed to delete uploaded files. Please try again." });
      }
    }
  }

  // 2) Delete user-scoped collections
  await Promise.all([
    healthRecords.deleteMany({ user_id: user._id }),
    db.collection("daily_metrics").deleteMany({ user_id: userIdStr }),
    db.collection("quick_logs").deleteMany({ user_id: userIdStr }),
    db.collection("chat_messages").deleteMany({ user_id: userIdStr }),
    db.collection("churn_events").deleteMany({ user_id: user._id }),
  ]);

  // 3) Delete user
  await users.deleteOne({ _id: user._id });

  return c.json({ status: "deleted" });
});

export default auth;

import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import { getDb } from "../db.js";
import { getCurrentUser } from "../middleware/auth.js";
import { updateProfileSchema, completeOnboardingSchema } from "../schemas/profile.js";
import { calculateAge, type User } from "../models/user.js";
import { userToResponse } from "../utils/user.js";

const profile = new Hono();

// GET /profile — return full user profile (exclude hashed_password)
profile.get("/", async (c) => {
  const user = await getCurrentUser(c);
  const { hashed_password, ...safeUser } = user as any;
  return c.json({
    ...safeUser,
    _id: user._id.toString(),
    age: calculateAge(user.date_of_birth),
  });
});

// PUT /profile — update profile fields
profile.put("/", async (c) => {
  const user = await getCurrentUser(c);
  const body = await c.req.json();
  const parsed = updateProfileSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(400, { message: "Invalid request body" });
  }

  const updates: Record<string, any> = { updated_at: new Date() };
  const data = parsed.data;

  if (data.full_name !== undefined) updates.full_name = data.full_name;
  if (data.date_of_birth !== undefined) updates.date_of_birth = new Date(data.date_of_birth);
  // Accept both "gender" and "biological_sex" (iOS sends biological_sex)
  const sex = data.gender ?? data.biological_sex;
  if (sex !== undefined) updates.gender = sex;
  if (data.dietary_preference !== undefined) updates.dietary_preference = data.dietary_preference;
  if (data.allergies !== undefined) updates.allergies = data.allergies;
  if (data.health_goals !== undefined) updates.health_goals = data.health_goals;
  if (data.health_conditions !== undefined) updates.health_conditions = data.health_conditions;

  const db = getDb();
  const users = db.collection<User>("users");
  await users.updateOne({ _id: user._id }, { $set: updates });
  const updated = await users.findOne({ _id: user._id });

  return c.json(userToResponse(updated!));
});

// POST /profile/onboarding — complete onboarding (batch save questionnaire)
profile.post("/onboarding", async (c) => {
  const user = await getCurrentUser(c);

  if (user.onboarding_completed) {
    throw new HTTPException(400, { message: "Onboarding already completed" });
  }

  const body = await c.req.json();
  const parsed = completeOnboardingSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(400, { message: "Invalid request body" });
  }

  const updates: Record<string, any> = {
    onboarding_completed: true,
    updated_at: new Date(),
  };
  const data = parsed.data;

  if (data.full_name) updates.full_name = data.full_name;
  if (data.date_of_birth) updates.date_of_birth = new Date(data.date_of_birth);
  // Accept both "gender" and "biological_sex" (iOS sends biological_sex)
  const sex = data.gender || data.biological_sex;
  if (sex) updates.gender = sex;
  if (data.dietary_preference) updates.dietary_preference = data.dietary_preference;
  if (data.allergies?.length) updates.allergies = data.allergies;
  if (data.health_goals?.length) updates.health_goals = data.health_goals;
  if (data.health_conditions?.length) updates.health_conditions = data.health_conditions;

  const db = getDb();
  const users = db.collection<User>("users");
  await users.updateOne({ _id: user._id }, { $set: updates });
  const updated = await users.findOne({ _id: user._id });

  return c.json(userToResponse(updated!));
});

export default profile;

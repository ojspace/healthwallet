import { Hono } from "hono";
import { HTTPException } from "hono/http-exception";
import * as jose from "jose";
import { getDb } from "../db.js";
import { createAccessToken } from "../middleware/auth.js";
import { rateLimit } from "../middleware/rate-limit.js";
import { createDefaultUser } from "../models/user.js";
import type { User } from "../models/user.js";
import { appleAuthSchema } from "../schemas/apple-auth.js";

const authApple = new Hono();

authApple.use("/apple", rateLimit({ windowMs: 60_000, max: 10, keyPrefix: "auth-apple" }));

// Cache Apple's JWKS for performance
const APPLE_JWKS = jose.createRemoteJWKSet(
  new URL("https://appleid.apple.com/auth/keys")
);

const APPLE_BUNDLE_ID = "mosaic.Healthwallet";

authApple.post("/apple", async (c) => {
  const body = await c.req.json();
  const parsed = appleAuthSchema.safeParse(body);

  if (!parsed.success) {
    throw new HTTPException(400, { message: "Invalid request body" });
  }

  const { identity_token, full_name } = parsed.data;

  // 1. Verify Apple identity token using JWKS
  let payload: jose.JWTPayload;
  try {
    const result = await jose.jwtVerify(identity_token, APPLE_JWKS, {
      issuer: "https://appleid.apple.com",
      audience: APPLE_BUNDLE_ID,
    });
    payload = result.payload;
  } catch (err) {
    throw new HTTPException(401, { message: "Invalid Apple identity token" });
  }

  const appleUserId = payload.sub;
  const email = payload.email as string | undefined;

  if (!appleUserId) {
    throw new HTTPException(401, { message: "Invalid token: missing subject" });
  }

  const db = getDb();
  const users = db.collection<User>("users");

  // 2. Find existing user by apple_id
  let user = await users.findOne({ apple_id: appleUserId });

  // 3. If not found by apple_id, try email linking
  if (!user && email) {
    user = await users.findOne({ email });
    if (user) {
      // Link existing email account with Apple
      await users.updateOne(
        { _id: user._id },
        { $set: { apple_id: appleUserId, updated_at: new Date() } }
      );
      user.apple_id = appleUserId;
    }
  }

  // 4. Create new user if not found
  if (!user) {
    const userData = createDefaultUser({
      email: email ?? `apple_${appleUserId}@private.appleid.com`,
      hashed_password: "", // No password for Apple users
      full_name: full_name ?? null,
      apple_id: appleUserId,
      auth_provider: "apple",
    });

    const result = await users.insertOne(userData as any);
    user = await users.findOne({ _id: result.insertedId });

    if (!user) {
      throw new HTTPException(500, { message: "Failed to create user" });
    }
  }

  if (!user.is_active) {
    throw new HTTPException(403, { message: "User account is deactivated" });
  }

  // 5. Generate JWT access token
  const accessToken = await createAccessToken(user._id.toHexString());

  return c.json({
    access_token: accessToken,
    token_type: "bearer",
    user: {
      id: user._id.toHexString(),
      email: user.email,
      full_name: user.full_name,
      subscription_tier: user.subscription_tier,
      onboarding_completed: user.onboarding_completed,
    },
  });
});

export default authApple;

import { Context, MiddlewareHandler } from "hono";
import { HTTPException } from "hono/http-exception";
import { SignJWT, jwtVerify } from "jose";
import { ObjectId } from "mongodb";
import { config } from "../config.js";
import { getDb } from "../db.js";
import type { User } from "../models/user.js";

const secret = new TextEncoder().encode(config.jwtSecretKey);

export function createAccessToken(userId: string, expiresInMinutes?: number): Promise<string> {
  const exp = expiresInMinutes ?? config.jwtAccessTokenExpireMinutes;
  return new SignJWT({ sub: userId })
    .setProtectedHeader({ alg: config.jwtAlgorithm })
    .setExpirationTime(`${exp}m`)
    .setIssuedAt()
    .sign(secret);
}

export async function decodeAccessToken(token: string): Promise<string | null> {
  try {
    const { payload } = await jwtVerify(token, secret, {
      algorithms: [config.jwtAlgorithm],
    });
    return (payload.sub as string) ?? null;
  } catch {
    return null;
  }
}

export async function getCurrentUser(c: Context): Promise<User> {
  const authHeader = c.req.header("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    throw new HTTPException(401, { message: "Could not validate credentials" });
  }

  const token = authHeader.slice(7);
  const userId = await decodeAccessToken(token);
  if (!userId) {
    throw new HTTPException(401, { message: "Could not validate credentials" });
  }

  let oid: ObjectId;
  try {
    oid = new ObjectId(userId);
  } catch {
    throw new HTTPException(401, { message: "Could not validate credentials" });
  }

  const db = getDb();
  const user = await db.collection<User>("users").findOne({ _id: oid });
  if (!user) {
    throw new HTTPException(401, { message: "Could not validate credentials" });
  }

  if (!user.is_active) {
    throw new HTTPException(403, { message: "User account is deactivated" });
  }

  return user;
}

/** Hono middleware that injects `user` into context variables */
export const authMiddleware: MiddlewareHandler = async (c, next) => {
  const user = await getCurrentUser(c);
  c.set("user", user);
  await next();
};

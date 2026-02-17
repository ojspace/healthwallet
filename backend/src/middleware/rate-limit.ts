import type { Context } from "hono";
import type { MiddlewareHandler } from "hono";

type RateLimitOptions = {
  windowMs: number;
  max: number;
  keyPrefix: string;
};

type Bucket = {
  count: number;
  resetAt: number;
};

const buckets = new Map<string, Bucket>();

function getClientIp(c: Context): string {
  const forwardedFor = c.req.header("x-forwarded-for");
  if (forwardedFor) return forwardedFor.split(",")[0]!.trim();

  const realIp = c.req.header("x-real-ip");
  if (realIp) return realIp.trim();

  const cfIp = c.req.header("cf-connecting-ip");
  if (cfIp) return cfIp.trim();

  return "unknown";
}

export function rateLimit({ windowMs, max, keyPrefix }: RateLimitOptions): MiddlewareHandler {
  return async (c, next) => {
    const ip = getClientIp(c);
    const key = `${keyPrefix}:${c.req.method}:${c.req.path}:${ip}`;
    const now = Date.now();

    const bucket = buckets.get(key);
    if (!bucket || bucket.resetAt <= now) {
      buckets.set(key, { count: 1, resetAt: now + windowMs });
      return next();
    }

    bucket.count += 1;
    if (bucket.count > max) {
      const retryAfterSeconds = Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
      c.header("Retry-After", retryAfterSeconds.toString());
      return c.json({ detail: "Too many requests. Please try again later." }, 429);
    }

    return next();
  };
}


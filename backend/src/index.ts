import { Hono } from "hono";
import { cors } from "hono/cors";
import { HTTPException } from "hono/http-exception";
import { connectDb } from "./db.js";
import { config } from "./config.js";
import auth from "./routes/auth.js";
import authApple from "./routes/auth-apple.js";
import records from "./routes/records.js";
import subscription from "./routes/subscription.js";
import churn from "./routes/churn.js";
import healthkit from "./routes/healthkit.js";
import quicklog from "./routes/quicklog.js";
import telegram from "./routes/telegram.js";
import affiliate from "./routes/affiliate.js";
import profile from "./routes/profile.js";
import chat from "./routes/chat.js";
import nutrition from "./routes/nutrition.js";

const app = new Hono();

// CORS
app.use("*", cors({
  origin: "*",
  allowMethods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowHeaders: ["Content-Type", "Authorization"],
}));

// Error handler
app.onError((err, c) => {
  if (err instanceof HTTPException) {
    return c.json({ detail: err.message }, err.status);
  }
  console.error("[Error]", err);
  return c.json({ detail: "Internal Server Error" }, 500);
});

// Health check
app.get("/", (c) => c.json({ message: "HealthWallet API", status: "healthy" }));
app.get("/health", (c) => c.json({ status: "ok" }));

// Routes
app.route("/api/v1/auth", auth);
app.route("/api/v1/auth", authApple);
app.route("/api/v1/records", records);
app.route("/api/v1/subscription", subscription);
app.route("/api/v1", churn);
app.route("/api/v1/healthkit", healthkit);
app.route("/api/v1/logs", quicklog);
app.route("/api/v1/telegram", telegram);
app.route("/api/v1/affiliate", affiliate);
app.route("/api/v1/profile", profile);
app.route("/api/v1/chat", chat);
app.route("/api/v1/nutrition", nutrition);

// Start server
const port = Number(config.port ?? 8000);

async function main() {
  await connectDb();
  console.log(`[${config.appName}] Server running on http://0.0.0.0:${port}`);
}

main().catch(console.error);

export default {
  port,
  fetch: app.fetch,
};

// Export app type for Hono RPC client
export type AppType = typeof app;

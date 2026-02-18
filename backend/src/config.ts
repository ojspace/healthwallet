export const config = {
  // App
  appName: process.env.APP_NAME ?? "HealthWallet API",
  debug: process.env.DEBUG === "true",
  port: Number(process.env.PORT ?? 8000),

  // Admin (used to protect /admin/* endpoints)
  adminEmails: (process.env.ADMIN_EMAILS ?? "")
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean),

  // MongoDB
  mongodbUrl: process.env.MONGODB_URL ?? "mongodb://localhost:27017",
  mongodbDbName: process.env.MONGODB_DB_NAME ?? "healthwallet",

  // JWT
  jwtSecretKey: process.env.JWT_SECRET_KEY ?? "your-secret-key-change-in-production",
  jwtAlgorithm: "HS256" as const,
  jwtAccessTokenExpireMinutes: Number(process.env.JWT_ACCESS_TOKEN_EXPIRE_MINUTES ?? 10080), // 7 days

  // Encryption (AES-256-GCM)
  encryptionKey: process.env.ENCRYPTION_KEY ?? process.env.FERNET_KEY ?? "your-encryption-key-change-in-production",

  // Google Gemini AI (legacy)
  googleApiKey: process.env.GOOGLE_API_KEY ?? "",

  // OpenRouter AI (primary)
  openrouterApiKey: process.env.OPENROUTER_API_KEY ?? "",
  openrouterModel: process.env.OPENROUTER_MODEL ?? "x-ai/grok-3-mini",

  // File Storage
  uploadDir: process.env.UPLOAD_DIR ?? "./uploads",
  maxUploadSizeMb: Number(process.env.MAX_UPLOAD_SIZE_MB ?? 10),

  // RevenueCat
  revenuecatWebhookSecret: process.env.REVENUECAT_WEBHOOK_SECRET ?? "",

  // Churnkey
  churnkeyWebhookSecret: process.env.CHURNKEY_WEBHOOK_SECRET ?? "",

  // Telegram Bot
  telegramBotToken: process.env.TELEGRAM_BOT_TOKEN ?? "",
  baseUrl: process.env.BASE_URL ?? "http://localhost:8000",

  // Affiliate
  amazonAffiliateTag: process.env.AMAZON_AFFILIATE_TAG ?? "",
  iherbAffiliateCode: process.env.IHERB_AFFILIATE_CODE ?? "",
} as const;

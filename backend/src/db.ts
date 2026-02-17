import { MongoClient, Db } from "mongodb";
import { config } from "./config.js";

let client: MongoClient | null = null;
let db: Db | null = null;

export async function connectDb(): Promise<Db> {
  if (db) return db;

  client = new MongoClient(config.mongodbUrl);
  await client.connect();
  db = client.db(config.mongodbDbName);

  // Ensure indexes
  await db.collection("users").createIndex({ email: 1 }, { unique: true });
  await db.collection("users").createIndex({ apple_id: 1 }, { sparse: true });
  await db.collection("users").createIndex({ telegram_id: 1 }, { sparse: true });
  await db.collection("health_records").createIndex({ user_id: 1 });
  await db.collection("daily_metrics").createIndex({ user_id: 1, date: -1 }, { unique: true });
  await db.collection("quick_logs").createIndex({ user_id: 1, date: -1 }, { unique: true });
  await db.collection("chat_messages").createIndex({ user_id: 1, created_at: -1 });

  console.log(`[DB] Connected to MongoDB: ${config.mongodbDbName}`);
  return db;
}

export function getDb(): Db {
  if (!db) throw new Error("Database not initialized. Call connectDb() first.");
  return db;
}

export async function closeDb(): Promise<void> {
  if (client) {
    await client.close();
    client = null;
    db = null;
  }
}

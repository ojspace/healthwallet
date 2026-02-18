import { config } from "../config.js";

const LINK_EXPIRY_MS = 10 * 60 * 1000; // 10 minutes

/** Derive an AES-256-GCM CryptoKey from the JWT secret. */
async function getKey(): Promise<CryptoKey> {
  const keyMaterial = new TextEncoder().encode(
    config.jwtSecretKey.padEnd(32, "0").slice(0, 32),
  );
  return crypto.subtle.importKey(
    "raw",
    keyMaterial,
    { name: "AES-GCM" },
    false,
    ["encrypt", "decrypt"],
  );
}

/**
 * Encrypt a user ID into a base64url deep-link payload.
 * The payload embeds a timestamp so it can expire after LINK_EXPIRY_MS.
 */
export async function encryptLinkPayload(userId: string): Promise<string> {
  const key = await getKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const data = JSON.stringify({ uid: userId, ts: Date.now() });
  const encoded = new TextEncoder().encode(data);
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    encoded,
  );

  // Combine iv + ciphertext into a single buffer, then base64url encode
  const combined = new Uint8Array(iv.length + new Uint8Array(encrypted).length);
  combined.set(iv);
  combined.set(new Uint8Array(encrypted), iv.length);

  return Buffer.from(combined).toString("base64url");
}

/**
 * Decrypt a deep-link payload back to the original user ID.
 * Returns null if the payload is invalid or has expired.
 */
export async function decryptLinkPayload(
  payload: string,
): Promise<string | null> {
  try {
    const key = await getKey();
    const combined = Buffer.from(payload, "base64url");
    const iv = combined.subarray(0, 12);
    const data = combined.subarray(12);

    const decrypted = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv },
      key,
      data,
    );
    const parsed = JSON.parse(new TextDecoder().decode(decrypted));

    // Check expiry
    if (Date.now() - parsed.ts > LINK_EXPIRY_MS) {
      return null;
    }

    return parsed.uid;
  } catch {
    return null;
  }
}

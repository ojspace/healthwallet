import { config } from "../config.js";

/**
 * AES-256-GCM encryption using Web Crypto API.
 * Format: base64(iv + ciphertext + authTag)
 */

let cryptoKey: CryptoKey | null = null;

async function getKey(): Promise<CryptoKey> {
  if (cryptoKey) return cryptoKey;

  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(config.encryptionKey.padEnd(32, "0").slice(0, 32)),
    "PBKDF2",
    false,
    ["deriveKey"]
  );

  cryptoKey = await crypto.subtle.deriveKey(
    {
      name: "PBKDF2",
      salt: new TextEncoder().encode("healthwallet-salt"),
      iterations: 100000,
      hash: "SHA-256",
    },
    keyMaterial,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"]
  );

  return cryptoKey;
}

export async function encryptData(data: string): Promise<string> {
  const key = await getKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(data);

  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    encoded
  );

  // Combine iv + ciphertext into single buffer
  const combined = new Uint8Array(iv.length + ciphertext.byteLength);
  combined.set(iv);
  combined.set(new Uint8Array(ciphertext), iv.length);

  return Buffer.from(combined).toString("base64");
}

export async function decryptData(encryptedBase64: string): Promise<string> {
  const key = await getKey();
  const combined = Buffer.from(encryptedBase64, "base64");

  const iv = combined.subarray(0, 12);
  const ciphertext = combined.subarray(12);

  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    key,
    ciphertext
  );

  return new TextDecoder().decode(decrypted);
}

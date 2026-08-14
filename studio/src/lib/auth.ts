/**
 * Minimal shared-password session handling.
 *
 * The studio proxies requests to fal.ai using a server-side API key, which
 * means an unprotected deployment would let anyone on the internet spend your
 * fal credits. Everything here exists to make sure that cannot happen.
 *
 * The session is a signed cookie rather than server-side state so that it works
 * on serverless hosts with no database. It is deliberately simple: swap
 * `verifyPassword` and `SESSION_COOKIE` for a real identity provider when the
 * studio grows past a single shared login.
 *
 * Uses Web Crypto only, so it runs unchanged in the Edge middleware runtime.
 */

export const SESSION_COOKIE = "fofv_studio_session";

/** How long a login lasts before the user has to re-enter the password. */
const SESSION_TTL_MS = 1000 * 60 * 60 * 24 * 14; // 14 days

const encoder = new TextEncoder();

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function getSecret(): string {
  const secret = process.env.SESSION_SECRET;
  if (!secret) {
    throw new Error(
      "SESSION_SECRET is not set. Generate one with: node -e \"console.log(require('crypto').randomBytes(32).toString('hex'))\"",
    );
  }
  return secret;
}

async function sign(payload: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(getSecret()),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
  return base64UrlEncode(new Uint8Array(signature));
}

/**
 * Compares two strings in constant time so that an attacker cannot recover the
 * password (or a valid signature) by measuring how long a comparison takes.
 */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}

/** Builds a signed `<expiry>.<signature>` cookie value. */
export async function createSessionToken(): Promise<string> {
  const expiresAt = String(Date.now() + SESSION_TTL_MS);
  return `${expiresAt}.${await sign(expiresAt)}`;
}

/** Returns true when the cookie is well-formed, correctly signed, and unexpired. */
export async function verifySessionToken(token: string | undefined): Promise<boolean> {
  if (!token) return false;

  const separator = token.lastIndexOf(".");
  if (separator === -1) return false;

  const expiresAt = token.slice(0, separator);
  const signature = token.slice(separator + 1);
  if (!/^\d+$/.test(expiresAt)) return false;
  if (Number(expiresAt) < Date.now()) return false;

  try {
    return timingSafeEqual(signature, await sign(expiresAt));
  } catch {
    // Missing SESSION_SECRET — fail closed rather than granting access.
    return false;
  }
}

/** Checks a submitted password against STUDIO_PASSWORD. */
export function verifyPassword(submitted: string): boolean {
  const expected = process.env.STUDIO_PASSWORD;
  if (!expected) {
    throw new Error("STUDIO_PASSWORD is not set, so nobody can sign in.");
  }
  return timingSafeEqual(submitted, expected);
}

export const sessionCookieOptions = {
  httpOnly: true,
  sameSite: "lax",
  secure: process.env.NODE_ENV === "production",
  path: "/",
  maxAge: SESSION_TTL_MS / 1000,
} as const;

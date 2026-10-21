import { createDecipheriv, createCipheriv, createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";

export const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const productKeyPattern = /^LB-AS-[0-9A-F]{64}$/;
export const appSumoCookies = { pending: "lb_as_pending", session: "lb_as_session" } as const;
const events = ["purchase", "activate", "upgrade", "downgrade", "deactivate"] as const;
export type AppSumoEvent = {
  event: typeof events[number]; license_key: string; prev_license_key?: string;
  tier?: number; test?: boolean; [key: string]: unknown;
};
export type AppSumoProfile = {
  id: string; status: "active" | "inactive" | "deactivated"; tier: number; macs: number;
  product_key: string | null; devices: { id: string; name: string; created_at: string }[];
};
export class AppSumoError extends Error {
  status: number;
  reason: string;
  constructor(status: number, reason = "unavailable") {
    super(reason); this.status = status; this.reason = reason;
  }
}

export function parseAppSumoEvent(value: unknown): AppSumoEvent {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new AppSumoError(400, "invalid");
  const body = value as Record<string, unknown>;
  if (!events.includes(body.event as AppSumoEvent["event"]) ||
      typeof body.license_key !== "string" || !uuidPattern.test(body.license_key) ||
      (body.test !== undefined && typeof body.test !== "boolean") ||
      (body.tier !== undefined && ![1, 2, 3].includes(body.tier as number)) ||
      (["activate", "upgrade", "downgrade"].includes(body.event as string) && body.tier === undefined) ||
      (["upgrade", "downgrade"].includes(body.event as string) &&
        (typeof body.prev_license_key !== "string" || !uuidPattern.test(body.prev_license_key) || body.prev_license_key === body.license_key)) ||
      body.parent_license_key != null) throw new AppSumoError(400, "invalid");
  return body as AppSumoEvent;
}

export function verifyAppSumoSignature(body: Uint8Array, timestamp: string | null, signature: string | null, secret: string, now = Date.now()) {
  if (!timestamp || !/^\d{10,13}$/.test(timestamp) || !signature || !/^[0-9a-f]{64}$/i.test(signature)) return false;
  const time = Number(timestamp) * (timestamp.length === 13 ? 1 : 1000);
  if (Math.abs(now - time) > 5 * 60 * 1000) return false;
  const expected = createHmac("sha256", secret).update(timestamp).update(body).digest();
  return timingSafeEqual(expected, Buffer.from(signature, "hex"));
}

export async function readSmallBody(request: Request, max = 16384) {
  if (Number(request.headers.get("content-length")) > max) throw new AppSumoError(413, "invalid");
  const reader = request.body?.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  if (reader) while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    length += value.length;
    if (length > max) { await reader.cancel(); throw new AppSumoError(413, "invalid"); }
    chunks.push(value);
  }
  return Buffer.concat(chunks);
}

function cookieKey(purpose: string) {
  const secret = process.env.APPSUMO_SESSION_SECRET;
  if (!secret || secret.length < 32) throw new AppSumoError(503);
  return createHash("sha256").update(`${purpose}:${secret}`).digest();
}
export function sealAppSumoCookie(purpose: "pending" | "session", value: object, seconds: number, now = Date.now()) {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", cookieKey(purpose), iv);
  const encrypted = Buffer.concat([cipher.update(JSON.stringify({ ...value, expires: now + seconds * 1000 })), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), encrypted]).toString("base64url");
}
export function openAppSumoCookie(purpose: "pending" | "session", value: string | undefined, now = Date.now()): Record<string, unknown> | null {
  try {
    if (!value || value.length > 6000) return null;
    const data = Buffer.from(value, "base64url");
    const decipher = createDecipheriv("aes-256-gcm", cookieKey(purpose), data.subarray(0, 12));
    decipher.setAuthTag(data.subarray(12, 28));
    const result = JSON.parse(Buffer.concat([decipher.update(data.subarray(28)), decipher.final()]).toString());
    return typeof result.expires === "number" && result.expires > now ? result : null;
  } catch { return null; }
}

export function appSumoRedirectURI() {
  const raw = process.env.APPSUMO_REDIRECT_URI;
  if (!raw) throw new AppSumoError(503);
  const url = new URL(raw);
  if (url.username || url.password || url.search || url.hash || url.pathname !== "/appsumo/callback" ||
      (url.protocol !== "https:" && !(url.protocol === "http:" && process.env.NODE_ENV !== "production" && ["localhost", "127.0.0.1"].includes(url.hostname)))) throw new AppSumoError(503);
  return url;
}
export function appSumoCookieOptions(seconds: number) {
  return { httpOnly: true, secure: appSumoRedirectURI().protocol === "https:", sameSite: "lax" as const, path: "/appsumo", maxAge: seconds };
}
export function checkAppSumoForm(request: Request, form: URLSearchParams, state: Record<string, unknown> | null) {
  if (request.headers.get("origin") !== appSumoRedirectURI().origin || !state || typeof state.nonce !== "string" || form.get("csrf") !== state.nonce) throw new AppSumoError(403, "expired");
}
export const appSumoHeaders = { "Cache-Control": "private, no-store", "Referrer-Policy": "no-referrer", "X-Robots-Tag": "noindex, nofollow" };

export function appSumoRateBucket(request: Request, scope: string) {
  const ip = request.headers.get("x-vercel-forwarded-for") ?? (process.env.NODE_ENV !== "production" ? request.headers.get("x-forwarded-for") : null) ?? "unknown";
  return scope + ":" + createHmac("sha256", cookieKey("rate")).update(ip.slice(0, 256)).digest("hex");
}

const licenseURL = "https://api.licensing.appsumo.com/v2/licenses/";
async function appSumoJSON(response: Response): Promise<Record<string, unknown>> {
  if (!response.ok) throw new AppSumoError(503);
  const data: unknown = await response.json();
  if (!data || typeof data !== "object" || Array.isArray(data)) throw new AppSumoError(503);
  return data as Record<string, unknown>;
}
export async function getAppSumoLicense(key: string, fetcher = fetch) {
  const secret = process.env.APPSUMO_PRIVATE_KEY;
  if (!secret || !uuidPattern.test(key)) throw new AppSumoError(503);
  const data = await appSumoJSON(await fetcher(licenseURL + key, {
    headers: { "X-AppSumo-Licensing-Key": secret }, cache: "no-store", redirect: "error", signal: AbortSignal.timeout(10000),
  }));
  if (data.license_key !== key || !["active", "inactive", "deactivated"].includes(data.status as string) || ![1, 2, 3].includes(data.tier as number)) throw new AppSumoError(503);
  return data as { license_key: string; status: string; tier: number };
}
export async function exchangeAppSumoCode(code: string, fetcher = fetch) {
  const clientId = process.env.APPSUMO_CLIENT_ID;
  const clientSecret = process.env.APPSUMO_CLIENT_SECRET;
  if (!clientId || !clientSecret) throw new AppSumoError(503);
  appSumoRedirectURI();
  const token = await appSumoJSON(await fetcher("https://appsumo.com/openid/token/", {
    method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: clientId, client_secret: clientSecret, redirect_uri: process.env.APPSUMO_REDIRECT_URI!, code, grant_type: "authorization_code" }),
    cache: "no-store", redirect: "error", signal: AbortSignal.timeout(10000),
  }));
  if (typeof token.access_token !== "string" || !token.access_token) throw new AppSumoError(403, "expired");
  // AppSumo documents this server-to-server endpoint with a query token.
  // It never appears in a browser URL, our logs, or an error sent to the buyer.
  const url = new URL("https://appsumo.com/openid/license_key/");
  url.searchParams.set("access_token", token.access_token);
  const data = await appSumoJSON(await fetcher(url, { cache: "no-store", redirect: "error", signal: AbortSignal.timeout(10000) }));
  if (data.status === "inactive") throw new AppSumoError(409, "pending");
  if (typeof data.license_key !== "string" || !uuidPattern.test(data.license_key) || data.status !== "active" ||
      !Array.isArray(data.scopes) || !data.scopes.includes("read_license")) throw new AppSumoError(403, "inactive");
  return data.license_key;
}

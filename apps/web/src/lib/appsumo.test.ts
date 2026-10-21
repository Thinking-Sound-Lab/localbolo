import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { after, before, test } from "node:test";
import {
  AppSumoError, appSumoRedirectURI, checkAppSumoForm, exchangeAppSumoCode, getAppSumoLicense,
  openAppSumoCookie, parseAppSumoEvent, readSmallBody, sealAppSumoCookie, verifyAppSumoSignature,
} from "./appsumo.ts";
import { handleAppSumoLicense, handleAppSumoWebhook } from "./appsumo-handlers.ts";

const original = { ...process.env };
const key = "22222222-2222-4222-8222-222222222222";
const previous = "11111111-1111-4111-8111-111111111111";
const productKey = "LB-AS-" + "A".repeat(64);
before(() => {
  process.env.APPSUMO_PRIVATE_KEY = "fixture-webhook-secret";
  process.env.APPSUMO_SESSION_SECRET = "fixture-cookie-secret-with-at-least-32-characters";
  process.env.APPSUMO_REDIRECT_URI = "https://localbolo.example/appsumo/callback";
  process.env.APPSUMO_CLIENT_ID = "fixture-client";
  process.env.APPSUMO_CLIENT_SECRET = "fixture-secret";
});
after(() => { process.env = original; });
function signed(body: object, timestamp = String(Math.floor(Date.now() / 1000))) {
  const raw = JSON.stringify(body);
  return new Request("https://localbolo.example/api/webhooks/appsumo", { method: "POST", body: raw, headers: {
    "x-appsumo-timestamp": timestamp,
    "x-appsumo-signature": createHmac("sha256", process.env.APPSUMO_PRIVATE_KEY!).update(timestamp + raw).digest("hex"),
  } });
}
function deps() {
  const calls: { name: string; args: Record<string, unknown> }[] = [];
  return { calls, rpc: async <T>(name: string, args: Record<string, unknown>) => { calls.push({ name, args }); return false as T; },
    rateLimit: async () => {}, license: async () => ({ license_key: key, status: "deactivated", tier: 2 }) };
}

test("signature binds timestamp and exact bytes, with a five minute replay window", () => {
  const body = Buffer.from('{"event":"purchase"}');
  const timestamp = "1800000000";
  const signature = createHmac("sha256", "secret").update(timestamp).update(body).digest("hex");
  assert(verifyAppSumoSignature(body, timestamp, signature, "secret", 1800000000000));
  assert(!verifyAppSumoSignature(Buffer.from('{ "event":"purchase"}'), timestamp, signature, "secret", 1800000000000));
  assert(!verifyAppSumoSignature(body, timestamp, signature, "other", 1800000000000));
  assert(!verifyAppSumoSignature(body, timestamp, signature, "secret", 1800000300001));
  assert(!verifyAppSumoSignature(body, timestamp, signature, "secret", 1799999699999));
  assert(!verifyAppSumoSignature(body, timestamp, "bad", "secret", 1800000000000));
});
test("cookies conceal credentials and reject tampering, expiration and the wrong purpose", () => {
  const token = sealAppSumoCookie("pending", { code: "private-code", nonce: "nonce" }, 300, 1000);
  assert(!token.includes("private-code"));
  assert.equal(openAppSumoCookie("pending", token, 1001)?.code, "private-code");
  assert.equal(openAppSumoCookie("pending", token, 301000), null);
  assert.equal(openAppSumoCookie("session", token, 1001), null);
  const modified = Buffer.from(token, "base64url"); modified[modified.length - 1] ^= 1;
  assert.equal(openAppSumoCookie("pending", modified.toString("base64url"), 1001), null);
});
test("buyer forms require both a same-origin POST and the cookie nonce", () => {
  const request = new Request("https://localbolo.example/appsumo/claim", { method: "POST", headers: { origin: "https://localbolo.example" } });
  checkAppSumoForm(request, new URLSearchParams({ csrf: "nonce" }), { nonce: "nonce" });
  assert.throws(() => checkAppSumoForm(request, new URLSearchParams({ csrf: "other" }), { nonce: "nonce" }), AppSumoError);
  assert.throws(() => checkAppSumoForm(new Request("https://localbolo.example/appsumo/claim", { headers: { origin: "https://attacker.example" } }), new URLSearchParams({ csrf: "nonce" }), { nonce: "nonce" }), AppSumoError);
  assert.throws(() => checkAppSumoForm(request, new URLSearchParams({ csrf: "old-nonce" }), null),
    (error: unknown) => error instanceof AppSumoError && error.status === 401 && error.reason === "expired");
  assert.throws(() => checkAppSumoForm(request, new URLSearchParams({ csrf: "wrong-nonce" }), { nonce: "nonce" }),
    (error: unknown) => error instanceof AppSumoError && error.status === 403 && error.reason === "invalid");
  assert.throws(() => checkAppSumoForm(new Request("https://localbolo.example/appsumo/claim"), new URLSearchParams(), null),
    (error: unknown) => error instanceof AppSumoError && error.status === 403);
});
test("events accept purchase/refund without a tier; tier changes require a previous key", () => {
  assert.equal(parseAppSumoEvent({ event: "purchase", license_key: key }).event, "purchase");
  assert.equal(parseAppSumoEvent({ event: "deactivate", license_key: key }).event, "deactivate");
  assert.equal(parseAppSumoEvent({ event: "activate", license_key: key, tier: 3, license_status: "inactive" }).tier, 3);
  for (const body of [
    { event: "activate", license_key: key, tier: 4 },
    { event: "upgrade", license_key: key, tier: 2 },
    { event: "downgrade", license_key: key, prev_license_key: key, tier: 1 },
    { event: "activate", license_key: key, tier: 1, parent_license_key: previous },
  ]) assert.throws(() => parseAppSumoEvent(body), AppSumoError);
});
test("redirect configuration rejects unsupported protocols and unexpected paths", () => {
  const configured = process.env.APPSUMO_REDIRECT_URI;
  try {
    for (const url of ["ftp://localhost/appsumo/callback", "https://localbolo.example/other", "https://user:password@localbolo.example/appsumo/callback", "https://localbolo.example/appsumo/callback?code=x"]) {
      process.env.APPSUMO_REDIRECT_URI = url;
      assert.throws(() => appSumoRedirectURI(), AppSumoError);
    }
  } finally { process.env.APPSUMO_REDIRECT_URI = configured; }
});
test("signed portal tests acknowledge without any database or provider call", async () => {
  const dependency = deps();
  dependency.rpc = async () => { throw Error("must not write"); };
  const response = await handleAppSumoWebhook(signed({ event: "upgrade", test: true }), dependency);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { event: "upgrade", success: true });
  const invalid = signed({ event: "activate", license_key: key, tier: 2 });
  invalid.headers.set("x-appsumo-signature", "0".repeat(64));
  assert.equal((await handleAppSumoWebhook(invalid, dependency)).status, 401);
});
test("webhook acknowledges only committed changes and does not trust license_status", async () => {
  const dependency = deps();
  const response = await handleAppSumoWebhook(signed({ event: "activate", license_key: key, tier: 2, license_status: "inactive" }), dependency);
  assert.equal(response.status, 200);
  assert.equal(dependency.calls.at(-1)?.name, "appsumo_apply_event");
  dependency.rpc = async () => { throw new AppSumoError(503); };
  assert.equal((await handleAppSumoWebhook(signed({ event: "deactivate", license_key: key }), dependency)).status, 503);
});
test("a delayed activation cannot resurrect a refund; verified reactivation can", async () => {
  for (const status of ["deactivated", "inactive", "active"]) {
    const dependency = deps();
    dependency.rpc = async <T>(name: string, args: Record<string, unknown>) => { dependency.calls.push({ name, args }); return true as T; };
    dependency.license = async () => ({ license_key: key, status, tier: 2 });
    assert.equal((await handleAppSumoWebhook(signed({ event: "activate", license_key: key, tier: 2 }), dependency)).status, 200);
    assert.equal(dependency.calls.at(-1)?.args.p_allow_reactivation, status !== "deactivated");
  }
});
test("a refund ACK must settle before API-confirmed reactivation", async () => {
  const dependency = deps();
  dependency.rpc = async <T>(name: string, args: Record<string, unknown>) => { dependency.calls.push({ name, args }); return (name === "appsumo_needs_reactivation") as T; };
  dependency.license = async () => ({ license_key: key, status: "active", tier: 2 });
  assert.equal((await handleAppSumoWebhook(signed({ event: "activate", license_key: key, tier: 2 }), dependency)).status, 503);
  assert(!dependency.calls.some(({ name }) => name === "appsumo_apply_event"));
});
test("oversize bodies are rejected even without a content-length", async () => {
  await assert.rejects(readSmallBody(new Request("https://localbolo.example", { method: "POST", body: "x".repeat(4097) }), 4096), (error: unknown) => error instanceof AppSumoError && error.status === 413);
});
test("Mac endpoints normalize keys, pass a stable device ID, and propagate limits", async () => {
  const dependency = deps();
  dependency.rpc = async <T>(name: string, args: Record<string, unknown>) => { dependency.calls.push({ name, args }); return { status: 422 } as T; };
  const response = await handleAppSumoLicense(new Request("https://localbolo.example/api/licenses/activate", {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ license_key: productKey.toLowerCase(), name: "My Mac", device_id: "a".repeat(64) }),
  }), "activate", dependency);
  assert.equal(response.status, 422);
  assert.equal(dependency.calls[0].args.p_key, productKey);
  assert.equal(dependency.calls[0].args.p_device, "a".repeat(64));
  assert.equal((await handleAppSumoLicense(new Request("https://localbolo.example", { method: "POST", body: "null", headers: { "content-type": "application/json" } }), "activate", dependency)).status, 400);
});
test("OAuth code is exchanged server-side with the exact redirect and scoped ownership", async () => {
  const calls: { url: string; init?: RequestInit }[] = [];
  const fixture = async (input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(input), init });
    return Response.json(calls.length === 1 ? { access_token: "fixture-token" } : { license_key: key, status: "active", scopes: ["read_license"] });
  };
  assert.equal(await exchangeAppSumoCode("fixture-code", fixture), key);
  assert.equal(calls[0].url, "https://appsumo.com/openid/token/");
  const form = calls[0].init?.body as URLSearchParams;
  assert.equal(form.get("redirect_uri"), process.env.APPSUMO_REDIRECT_URI);
  assert.equal(form.get("code"), "fixture-code");
  assert.equal(form.get("grant_type"), "authorization_code");
  assert.equal(new URL(calls[1].url).searchParams.get("access_token"), "fixture-token");
  for (const [status, scopes, reason] of [["active", [], "inactive"], ["inactive", ["read_license"], "pending"], ["deactivated", ["read_license"], "inactive"]] as const) {
    let attempt = 0;
    await assert.rejects(exchangeAppSumoCode("fixture-code", async () => Response.json(++attempt === 1 ? { access_token: "fixture-token" } : { license_key: key, status, scopes })),
      (error: unknown) => error instanceof AppSumoError && error.reason === reason);
  }
});
test("private API lookup binds both the returned key and a supported tier", async () => {
  assert.deepEqual(await getAppSumoLicense(key, async (url, init) => {
    assert.equal(String(url), "https://api.licensing.appsumo.com/v2/licenses/" + key);
    assert.equal((init?.headers as Record<string, string>)["X-AppSumo-Licensing-Key"], process.env.APPSUMO_PRIVATE_KEY);
    return Response.json({ license_key: key, status: "active", tier: 3 });
  }), { license_key: key, status: "active", tier: 3 });
  for (const data of [{ license_key: previous, status: "active", tier: 1 }, { license_key: key, status: "active", tier: 9 }]) {
    await assert.rejects(getAppSumoLicense(key, async () => Response.json(data)), AppSumoError);
  }
});

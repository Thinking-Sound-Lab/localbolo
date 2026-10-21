import assert from "node:assert/strict";
import { test } from "node:test";
import type { SupabaseClient } from "@supabase/supabase-js";
import { AppSumoError } from "./appsumo.ts";
import { appSumoRPC } from "./appsumo-store.ts";

test("RPC failures record only the operation and safe database code", async (t) => {
  const log = t.mock.method(console, "error", () => {});
  for (const [code, expected] of [["23505", "23505"], ["PGRST202", "PGRST202"], ["private-key-in-code", "unknown"]]) {
    const db = { rpc: async () => ({ data: null, error: {
      code, message: "private-message", details: "private-key", hint: "private-payload",
    } }) } as unknown as SupabaseClient;
    await assert.rejects(appSumoRPC("appsumo_claim", { p_key: "buyer-key" }, db),
      (error: unknown) => error instanceof AppSumoError && error.status === 503 && error.reason === "unavailable");
    assert.deepEqual(log.mock.calls.at(-1)?.arguments, ["AppSumo database request failed", { operation: "appsumo_claim", code: expected }]);
  }
  assert(!JSON.stringify(log.mock.calls.map((call) => call.arguments)).match(/private-|buyer-key/));
});

test("successful RPC calls do not log credentials or results", async (t) => {
  const log = t.mock.method(console, "error", () => {});
  const db = { rpc: async () => ({ data: { product_key: "private-key" }, error: null }) } as unknown as SupabaseClient;
  assert.deepEqual(await appSumoRPC("appsumo_claim", { p_key: "buyer-key" }, db), { product_key: "private-key" });
  assert.equal(log.mock.calls.length, 0);
});

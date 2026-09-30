import assert from "node:assert/strict";
import { describe, test } from "node:test";
import type { SupabaseClient } from "@supabase/supabase-js";
import type DodoPayments from "dodopayments";
import { purchaseChange, purchaseStatus, recordPurchase } from "./purchases.ts";

describe("purchaseStatus", () => {
  const cases: [string, Partial<DodoPayments.Payment>, string][] = [
    ["a payment with no refunds or disputes", {}, "paid"],
    ["a partial refund", { refund_status: "partial" }, "partially_refunded"],
    ["a full refund", { refund_status: "full" }, "refunded"],
    ["an open dispute", { disputes: [dispute("dispute_opened")] }, "disputed"],
    ["a challenged dispute", { disputes: [dispute("dispute_challenged")] }, "disputed"],
    ["a won dispute", { disputes: [dispute("dispute_won")] }, "paid"],
    ["a cancelled dispute", { disputes: [dispute("dispute_cancelled")] }, "paid"],
    ["a lost dispute", { disputes: [dispute("dispute_lost")] }, "charged_back"],
    ["an accepted dispute", { disputes: [dispute("dispute_accepted")] }, "charged_back"],
    ["an expired dispute", { disputes: [dispute("dispute_expired")] }, "charged_back"],
    ["a dispute opened after a refund", { refund_status: "full", disputes: [dispute("dispute_opened")] }, "disputed"],
  ];
  for (const [name, changes, expected] of cases) {
    test(`${name} is ${expected}`, () => {
      assert.equal(purchaseStatus(payment(changes)), expected);
    });
  }
});

describe("recordPurchase", () => {
  test("records a successful payment", async () => {
    const { database, rows } = fakeDatabase();

    await recordPurchase(database, fakeDodo(payment()), "pay_1");

    assert.deepEqual(withoutUpdatedAt(rows.get("pay_1")), {
      payment_id: "pay_1",
      customer_id: "cus_1",
      email: "buyer@example.com",
      name: "A Buyer",
      country: "IN",
      amount: 4900,
      currency: "USD",
      status: "paid",
      purchased_at: "2026-09-29T10:00:00Z",
    });
  });

  test("keeps the license key's ID when a later event doesn't know it", async () => {
    const { database, rows } = fakeDatabase();

    await recordPurchase(database, fakeDodo(payment()), "pay_1", "lic_1");
    await recordPurchase(database, fakeDodo(payment({ refund_status: "full" })), "pay_1");

    assert.equal(rows.get("pay_1")?.license_key_id, "lic_1");
    assert.equal(rows.get("pay_1")?.status, "refunded");
  });

  test("leaves out payments that didn't go through", async () => {
    const { database, writes } = fakeDatabase();

    await recordPurchase(database, fakeDodo(payment({ status: "failed" })), "pay_1");

    assert.equal(writes.length, 0);
  });

  test("writes again when the payment changed while it was being recorded", async () => {
    const { database, rows, writes } = fakeDatabase();
    // Refunded after the first look, as when a refund's webhook overlaps this one.
    const dodo = fakeDodo(payment(), payment({ refund_status: "full" }));

    await recordPurchase(database, dodo, "pay_1");

    assert.deepEqual(
      writes.map((row) => row.status),
      ["paid", "refunded"],
    );
    assert.equal(rows.get("pay_1")?.status, "refunded");
  });

  test("gives up, so Dodo retries, if the payment keeps changing", async () => {
    const { database } = fakeDatabase();
    const states = [payment(), payment({ refund_status: "partial" }), payment({ refund_status: "full" })];
    const dodo = fakeDodo(...states, ...states);

    await assert.rejects(recordPurchase(database, dodo, "pay_1"), /kept changing/);
  });

  test("reports a failed write", async () => {
    const { database } = fakeDatabase({ error: { message: "permission denied" } });

    await assert.rejects(recordPurchase(database, fakeDodo(payment()), "pay_1"), /permission denied/);
  });
});

describe("purchaseChange", () => {
  test("a payment event changes its purchase", () => {
    assert.deepEqual(purchaseChange(event("payment.succeeded", { payment_id: "pay_1" })), { paymentId: "pay_1" });
    assert.deepEqual(purchaseChange(event("dispute.expired", { payment_id: "pay_1" })), { paymentId: "pay_1" });
  });

  test("a new license key is recorded with its purchase", () => {
    assert.deepEqual(purchaseChange(event("license_key.created", { id: "lic_1", payment_id: "pay_1" })), {
      paymentId: "pay_1",
      licenseKeyId: "lic_1",
    });
  });

  test("a license key made by hand, or a failed payment, changes nothing", () => {
    assert.equal(purchaseChange(event("license_key.created", { id: "lic_1", payment_id: null })), undefined);
    assert.equal(purchaseChange(event("payment.failed", { payment_id: "pay_1" })), undefined);
  });
});

// MARK: - Helpers

function payment(changes: Partial<DodoPayments.Payment> = {}) {
  return {
    payment_id: "pay_1",
    status: "succeeded",
    customer: { customer_id: "cus_1", email: "buyer@example.com", name: "A Buyer" },
    billing: { country: "IN" },
    total_amount: 4900,
    currency: "USD",
    created_at: "2026-09-29T10:00:00Z",
    refund_status: null,
    disputes: [],
    ...changes,
  } as DodoPayments.Payment;
}

function dispute(dispute_status: DodoPayments.Dispute["dispute_status"]) {
  return { dispute_status } as DodoPayments.Dispute;
}

function event(type: string, data: object) {
  return { type, data } as DodoPayments.UnwrapWebhookEvent;
}

/** Dodo, answering each look at the payment with the next state, then the last one again. */
function fakeDodo(...states: DodoPayments.Payment[]) {
  let looks = 0;
  const retrieve = async () => states[Math.min(looks++, states.length - 1)];
  return { payments: { retrieve } } as unknown as DodoPayments;
}

/** Supabase's purchases table, merging each upsert like Postgres does. */
function fakeDatabase(result: { error: { message: string } | null } = { error: null }) {
  const rows = new Map<string, Record<string, unknown>>();
  const writes: Record<string, unknown>[] = [];
  const upsert = async (row: Record<string, unknown>) => {
    if (result.error) return result;
    writes.push(row);
    const id = row.payment_id as string;
    rows.set(id, { ...rows.get(id), ...row });
    return result;
  };
  const database = { from: () => ({ upsert }) } as unknown as SupabaseClient;
  return { database, rows, writes };
}

function withoutUpdatedAt(row: Record<string, unknown> | undefined) {
  const { updated_at, ...rest } = row ?? {};
  assert.equal(typeof updated_at, "string");
  return rest;
}

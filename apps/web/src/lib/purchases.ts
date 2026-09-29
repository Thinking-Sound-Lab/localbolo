import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type DodoPayments from "dodopayments";

/*
 * A record of everyone who has bought LocalBolo, kept in Supabase's purchases
 * table (see supabase/migrations). Dodo Payments' webhooks say when a payment
 * changes, and each time the payment is fetched fresh from Dodo, so events
 * that arrive late, twice or out of order still leave the right record.
 */

export type PurchaseStatus = "paid" | "partially_refunded" | "refunded" | "disputed" | "charged_back";

/** How many times to write a purchase whose payment keeps changing meanwhile. */
const maxAttempts = 3;

/**
 * Supabase with the secret key, which can read and write purchases, or null
 * when it isn't configured. Server only: the key must never reach a browser.
 */
export function purchasesDatabase() {
  const url = process.env.SUPABASE_URL;
  const secretKey = process.env.SUPABASE_SECRET_KEY;
  if (!url || !secretKey) return null;

  return createClient(url, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** The purchase a webhook event changes, if it changes one. */
export function purchaseChange(event: DodoPayments.UnwrapWebhookEvent) {
  switch (event.type) {
    case "payment.succeeded":
    case "refund.succeeded":
    case "dispute.opened":
    case "dispute.challenged":
    case "dispute.won":
    case "dispute.lost":
    case "dispute.accepted":
    case "dispute.cancelled":
    case "dispute.expired":
      return { paymentId: event.data.payment_id };
    case "license_key.created":
      // Keys made by hand in the dashboard have no payment.
      return event.data.payment_id ? { paymentId: event.data.payment_id, licenseKeyId: event.data.id } : undefined;
    default:
      return undefined;
  }
}

/**
 * Records a payment's current state as a purchase. Payments that didn't go
 * through aren't purchases, so they're left out.
 */
export async function recordPurchase(
  database: SupabaseClient,
  dodo: DodoPayments,
  paymentId: string,
  licenseKeyId?: string,
) {
  let payment = await dodo.payments.retrieve(paymentId);
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    if (payment.status !== "succeeded") return;

    const status = purchaseStatus(payment);
    const { error } = await database.from("purchases").upsert({
      payment_id: payment.payment_id,
      customer_id: payment.customer.customer_id,
      email: payment.customer.email,
      name: payment.customer.name,
      country: payment.billing.country,
      amount: payment.total_amount,
      currency: payment.currency,
      status,
      purchased_at: payment.created_at,
      updated_at: new Date().toISOString(),
      // Only sent when known, so recording a refund never clears it.
      ...(licenseKeyId && { license_key_id: licenseKeyId }),
    });
    if (error) throw new Error(`Couldn't record purchase ${paymentId}: ${error.message}`);

    // Another event for this payment may have landed first with a newer state,
    // which this write just replaced. Every write is followed by a fresh look,
    // so whichever write lands last is checked against Dodo after it.
    payment = await dodo.payments.retrieve(paymentId);
    if (purchaseStatus(payment) === status) return;
  }
  throw new Error(`Payment ${paymentId} kept changing while it was being recorded`);
}

/** Where a successful payment stands now, after any refunds and disputes. */
export function purchaseStatus(payment: Pick<DodoPayments.Payment, "refund_status" | "disputes">): PurchaseStatus {
  const disputes = payment.disputes.map((dispute) => dispute.dispute_status);
  // An expired dispute ran out of time for a response, which Dodo says
  // typically resolves against the seller.
  if (disputes.some((status) => status === "dispute_lost" || status === "dispute_accepted" || status === "dispute_expired")) {
    return "charged_back";
  }
  if (disputes.some((status) => status === "dispute_opened" || status === "dispute_challenged")) return "disputed";
  if (payment.refund_status === "full") return "refunded";
  if (payment.refund_status === "partial") return "partially_refunded";
  return "paid";
}

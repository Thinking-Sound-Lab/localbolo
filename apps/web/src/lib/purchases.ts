import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type DodoPayments from "dodopayments";

/*
 * A record of everyone who has bought LocalBolo, kept in Supabase's purchases
 * table (see supabase/migrations). Dodo Payments' webhooks say when a payment
 * changes, and each time the payment is fetched fresh from Dodo, so events
 * that arrive late, twice or out of order still leave the right record.
 */

export type PurchaseStatus = "paid" | "partially_refunded" | "refunded" | "disputed" | "charged_back";

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
  const payment = await dodo.payments.retrieve(paymentId);
  if (payment.status !== "succeeded") return;

  const { error } = await database.from("purchases").upsert({
    payment_id: payment.payment_id,
    customer_id: payment.customer.customer_id,
    email: payment.customer.email,
    name: payment.customer.name,
    country: payment.billing.country,
    amount: payment.total_amount,
    currency: payment.currency,
    status: purchaseStatus(payment),
    purchased_at: payment.created_at,
    updated_at: new Date().toISOString(),
    // Only sent when known, so recording a refund never clears it.
    ...(licenseKeyId && { license_key_id: licenseKeyId }),
  });
  if (error) throw new Error(`Couldn't record purchase ${paymentId}: ${error.message}`);
}

/** Where a successful payment stands now, after any refunds and disputes. */
export function purchaseStatus(payment: Pick<DodoPayments.Payment, "refund_status" | "disputes">): PurchaseStatus {
  const disputes = payment.disputes.map((dispute) => dispute.dispute_status);
  if (disputes.includes("dispute_lost") || disputes.includes("dispute_accepted")) return "charged_back";
  if (disputes.includes("dispute_opened") || disputes.includes("dispute_challenged")) return "disputed";
  if (payment.refund_status === "full") return "refunded";
  if (payment.refund_status === "partial") return "partially_refunded";
  return "paid";
}

import { dodoClient } from "@/lib/dodo";
import { purchaseChange, purchasesDatabase, recordPurchase } from "@/lib/purchases";

/**
 * Receives Dodo Payments webhooks (Dashboard › Developer › Webhooks).
 *
 * Dodo fulfils each purchase itself: it emails the receipt, the download and
 * any license key. This endpoint verifies each event's signature and keeps the
 * record of who bought LocalBolo in Supabase up to date as payments succeed,
 * are refunded or disputed, and get their license keys. The server log gets
 * IDs only, never customers' details.
 */
export async function POST(request: Request) {
  const dodo = dodoClient();
  const database = purchasesDatabase();
  if (!dodo || !process.env.DODO_PAYMENTS_WEBHOOK_KEY || !database) {
    console.error(
      "Dodo webhook received, but DODO_PAYMENTS_API_KEY, DODO_PAYMENTS_WEBHOOK_KEY, SUPABASE_URL or SUPABASE_SECRET_KEY isn't set.",
    );
    // A non-2xx response makes Dodo retry later, once everything is set.
    return Response.json({ error: "Webhooks aren't configured" }, { status: 503 });
  }

  // Verification needs the exact bytes Dodo signed, so read the raw body.
  const body = await request.text();
  let event;
  try {
    event = dodo.webhooks.unwrap(body, {
      headers: {
        "webhook-id": request.headers.get("webhook-id") ?? "",
        "webhook-signature": request.headers.get("webhook-signature") ?? "",
        "webhook-timestamp": request.headers.get("webhook-timestamp") ?? "",
      },
    });
  } catch {
    return Response.json({ error: "Invalid signature" }, { status: 401 });
  }

  const change = purchaseChange(event);
  if (!change) return Response.json({ received: true });

  try {
    await recordPurchase(database, dodo, change.paymentId, change.licenseKeyId);
  } catch (error) {
    console.error(`Couldn't record Dodo ${event.type}:`, error);
    // Dodo retries, and recording the same event twice is harmless.
    return Response.json({ error: "Couldn't record the event" }, { status: 500 });
  }

  if (event.type === "dispute.opened") {
    console.warn(`Dodo ${event.type}: respond in the Dodo dashboard`, { paymentId: change.paymentId });
  } else {
    console.info(`Recorded Dodo ${event.type}`, { paymentId: change.paymentId });
  }
  return Response.json({ received: true });
}


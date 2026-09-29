import { dodoClient } from "@/lib/dodo";

/**
 * Receives Dodo Payments webhooks (Dashboard › Developer › Webhooks).
 *
 * Dodo fulfils each purchase itself: it emails the receipt, the download and
 * any license key. So this endpoint verifies each event's signature and
 * records sales, refunds and disputes in the server log, where they can be
 * monitored. It logs IDs and amounts, never customers' details.
 */
export async function POST(request: Request) {
  const dodo = dodoClient();
  if (!dodo || !process.env.DODO_PAYMENTS_WEBHOOK_KEY) {
    console.error("Dodo webhook received, but DODO_PAYMENTS_API_KEY or DODO_PAYMENTS_WEBHOOK_KEY isn't set.");
    // A non-2xx response makes Dodo retry later, once the keys are set.
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

  switch (event.type) {
    case "payment.succeeded":
    case "payment.failed":
      console.info(`Dodo ${event.type}`, {
        paymentId: event.data.payment_id,
        amount: event.data.total_amount,
        currency: event.data.currency,
      });
      break;
    case "refund.succeeded":
      console.info(`Dodo ${event.type}`, {
        refundId: event.data.refund_id,
        paymentId: event.data.payment_id,
        amount: event.data.amount,
        currency: event.data.currency,
      });
      break;
    case "dispute.opened":
      console.warn(`Dodo ${event.type}: respond in the Dodo dashboard`, {
        disputeId: event.data.dispute_id,
        paymentId: event.data.payment_id,
      });
      break;
  }

  return Response.json({ received: true });
}

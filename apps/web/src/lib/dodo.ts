import DodoPayments from "dodopayments";

/*
 * Dodo Payments sells LocalBolo as the merchant of record: it runs checkout,
 * charges tax, emails the receipt and delivers the download. It's configured
 * with server-only environment variables; see .env.local.example.
 */

/** Test mode unless explicitly set to live, so a missing variable never charges real cards. */
const environment =
  process.env.DODO_PAYMENTS_ENVIRONMENT === "live_mode" ? "live_mode" : "test_mode";

/** The Dodo product that is LocalBolo for Mac. */
export const dodoProductId = process.env.DODO_PAYMENTS_PRODUCT_ID;

/**
 * A Dodo Payments client, or null when the API key isn't set. Create one per
 * request, so the site still builds without the secrets.
 */
export function dodoClient() {
  const apiKey = process.env.DODO_PAYMENTS_API_KEY;
  if (!apiKey) return null;

  return new DodoPayments({
    bearerToken: apiKey,
    webhookKey: process.env.DODO_PAYMENTS_WEBHOOK_KEY ?? null,
    environment,
  });
}

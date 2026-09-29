/**
 * "Lost your key?": sends buyers to Dodo's customer portal, where they enter
 * the email they bought with and get a sign-in link that shows their license
 * key. The app and the support page link here, so the portal's address can
 * change without an app update.
 */
export function GET(request: Request) {
  const businessId = process.env.DODO_PAYMENTS_BUSINESS_ID;
  if (!businessId) {
    return Response.redirect(new URL("/support#lost-key", request.url), 307);
  }

  const portal =
    process.env.DODO_PAYMENTS_ENVIRONMENT === "live_mode"
      ? "https://customer.dodopayments.com"
      : "https://test.customer.dodopayments.com";
  return Response.redirect(`${portal}/login/${encodeURIComponent(businessId)}`, 307);
}

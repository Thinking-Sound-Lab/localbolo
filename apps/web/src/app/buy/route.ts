import { dodoClient, dodoProductId } from "@/lib/dodo";

/**
 * Starts a purchase: creates a Dodo Payments checkout session for LocalBolo
 * and sends the visitor to Dodo's hosted checkout. Dodo sends them back to
 * /purchase with the outcome.
 */
export async function GET(request: Request) {
  const dodo = dodoClient();
  if (!dodo || !dodoProductId) {
    console.error("Checkout isn't configured: set DODO_PAYMENTS_API_KEY and DODO_PAYMENTS_PRODUCT_ID.");
    return redirectToOutcome(request, "unavailable");
  }

  try {
    const session = await dodo.checkoutSessions.create({
      product_cart: [{ product_id: dodoProductId, quantity: 1 }],
      // Back to the site the visitor came from, so previews and local runs work too.
      return_url: new URL("/purchase", request.url).toString(),
    });
    if (!session.checkout_url) throw new Error("Dodo returned no checkout URL");

    return Response.redirect(session.checkout_url, 303);
  } catch (error) {
    console.error("Couldn't create a Dodo checkout session:", error);
    return redirectToOutcome(request, "unavailable");
  }
}

function redirectToOutcome(request: Request, status: string) {
  const url = new URL("/purchase", request.url);
  url.searchParams.set("status", status);
  return Response.redirect(url, 303);
}

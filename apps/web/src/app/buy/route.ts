import { dodoClient } from "@/lib/dodo";
import { createPlanCheckout } from "@/lib/checkout";
import { licensePlan } from "@/lib/pricing";

/**
 * Starts a purchase: creates a Dodo Payments checkout session for LocalBolo
 * and sends the visitor to Dodo's hosted checkout. Dodo sends them back to
 * /purchase with the outcome.
 */
export async function GET(request: Request) {
  const plan = licensePlan(new URL(request.url).searchParams.get("plan"));
  if (!plan) return Response.json({ error: "Unknown license plan" }, { status: 400 });
  const dodo = dodoClient();
  const productId = process.env[plan.productEnv];
  if (!dodo || !productId) {
    console.error(`Checkout isn't configured for the ${plan.id} plan.`);
    return redirectToOutcome(request, "unavailable");
  }

  try {
    const checkoutUrl = await createPlanCheckout(dodo, plan, productId, request.url);
    return Response.redirect(checkoutUrl, 303);
  } catch (error) {
    // The reason is a catalog mismatch or Dodo's API error, never a secret.
    const reason = error instanceof Error ? error.message : String(error);
    console.error(`Couldn't create a matching Dodo checkout for the ${plan.id} plan: ${reason}`);
    return redirectToOutcome(request, "unavailable");
  }
}

function redirectToOutcome(request: Request, status: string) {
  const url = new URL("/purchase", request.url);
  url.searchParams.set("status", status);
  return Response.redirect(url, 303);
}

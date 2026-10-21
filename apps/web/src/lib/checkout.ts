import type DodoPayments from "dodopayments";
import type { LicensePlan } from "./pricing.ts";

/** Reject stale catalog settings before charging a buyer or issuing the wrong keys. */
export function verifyPlanProduct(product: DodoPayments.Product, plan: LicensePlan) {
  const price = product.price;
  if (product.is_recurring || price.type !== "one_time_price" || price.currency !== "USD" ||
      price.price !== plan.price * 100 || price.pay_what_you_want ||
      price.purchasing_power_parity || price.discount || price.discount_bps || product.pricing_mode) {
    throw new Error("The Dodo product does not match the advertised plan price");
  }
  const keys = product.entitlements.filter((item) => item.integration_type === "license_key");
  const config = keys[0]?.integration_config;
  if (keys.length !== 1 || !config || !("activations_limit" in config) || config.activations_limit !== plan.macs ||
      ("duration_count" in config && config.duration_count != null) ||
      ("duration_interval" in config && config.duration_interval != null) ||
      ("fulfillment_mode" in config && config.fulfillment_mode === "manual")) {
    throw new Error("The Dodo product must issue one non-expiring key with the selected Mac limit");
  }
}

export async function createPlanCheckout(
  dodo: DodoPayments,
  plan: LicensePlan,
  productId: string,
  origin: string,
) {
  verifyPlanProduct(await dodo.products.retrieve(productId), plan);
  const options: DodoPayments.CheckoutSessionCreateParams = {
    product_cart: [{ product_id: productId, quantity: 1 }],
    billing_currency: "USD",
    feature_flags: { allow_currency_selection: false },
    metadata: { localbolo_plan: plan.id, localbolo_macs: String(plan.macs) },
    return_url: new URL("/purchase", origin).toString(),
    cancel_url: new URL("/#pricing", origin).toString(),
  };
  const quote = await dodo.checkoutSessions.preview(options);
  if (quote.currency !== "USD" || quote.current_breakup.subtotal !== plan.price * 100 ||
      quote.product_cart.length !== 1 || quote.product_cart[0].quantity !== 1 ||
      quote.product_cart[0].product_id !== productId) {
    throw new Error("The checkout quote does not match the advertised plan");
  }
  const session = await dodo.checkoutSessions.create(options);
  if (!session.checkout_url) throw new Error("Dodo returned no checkout URL");
  return session.checkout_url;
}

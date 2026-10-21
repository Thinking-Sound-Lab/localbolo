import assert from "node:assert/strict";
import { describe, test } from "node:test";
import type DodoPayments from "dodopayments";
import { createPlanCheckout } from "./checkout.ts";
import { licensePlan, licensePlans } from "./pricing.ts";

function provider(plan = licensePlans[0] as (typeof licensePlans)[number]) {
  const product = {
    product_id: "pdt_plan",
    is_recurring: false,
    price: { type: "one_time_price", price: plan.price * 100, currency: "USD" },
    entitlements: [{ id: "ent_key", name: "One Mac", integration_type: "license_key", integration_config: { activations_limit: plan.macs } }],
  } as DodoPayments.Product;
  const quote = {
    currency: "USD",
    current_breakup: { subtotal: plan.price * 100 },
    product_cart: [{ product_id: "pdt_plan", quantity: 1 }],
  } as DodoPayments.CheckoutSessionPreviewResponse;
  const requests: DodoPayments.CheckoutSessionCreateParams[] = [];
  const dodo = {
    products: { retrieve: async () => product },
    checkoutSessions: {
      preview: async () => quote,
      create: async (args: DodoPayments.CheckoutSessionCreateParams) => {
        requests.push(args);
        return { checkout_url: "https://checkout.dodopayments.com/test" };
      },
    },
  } as unknown as DodoPayments;
  return { dodo, product, quote, requests };
}

describe("license checkout", () => {
  for (const plan of licensePlans) {
    test(`${plan.name} charges ${plan.label} and issues one key for ${plan.macs} Macs`, async () => {
      const { dodo, requests } = provider(plan);
      const url = await createPlanCheckout(dodo, plan, "pdt_plan", "https://localbolo.app/buy");
      assert.equal(url, "https://checkout.dodopayments.com/test");
      assert.deepEqual(requests[0].product_cart, [{ product_id: "pdt_plan", quantity: 1 }]);
      assert.equal(requests[0].billing_currency, "USD");
      assert.equal(requests[0].return_url, "https://localbolo.app/purchase");
    });
  }

  test("an existing two-Mac product cannot silently fulfill a new one-Mac plan", async () => {
    const { dodo, product, requests } = provider();
    product.entitlements[0].integration_config = { activations_limit: 2 };
    await assert.rejects(createPlanCheckout(dodo, licensePlans[0], "pdt_plan", "https://localbolo.app"), /selected Mac limit/);
    assert.equal(requests.length, 0);
  });

  test("a changed or localized quote cannot charge more than the advertised price", async () => {
    const { dodo, quote, requests } = provider();
    quote.current_breakup.subtotal = 4999;
    await assert.rejects(createPlanCheckout(dodo, licensePlans[0], "pdt_plan", "https://localbolo.app"), /quote/);
    assert.equal(requests.length, 0);
  });

  test("a plan cannot silently issue multiple license keys", async () => {
    const { dodo, quote, requests } = provider(licensePlans[2]);
    quote.product_cart[0].quantity = 2;
    await assert.rejects(createPlanCheckout(dodo, licensePlans[2], "pdt_plan", "https://localbolo.app"), /quote/);
    assert.equal(requests.length, 0);
  });

  test("an expiring or manually fulfilled key cannot be sold as instant lifetime access", async () => {
    const { dodo, product } = provider();
    product.entitlements[0].integration_config = { activations_limit: 1, duration_count: 1, duration_interval: "Year" };
    await assert.rejects(createPlanCheckout(dodo, licensePlans[0], "pdt_plan", "https://localbolo.app"), /non-expiring/);
    product.entitlements[0].integration_config = { activations_limit: 1, fulfillment_mode: "manual" };
    await assert.rejects(createPlanCheckout(dodo, licensePlans[0], "pdt_plan", "https://localbolo.app"), /non-expiring/);
  });

  test("unknown plan IDs cannot select an arbitrary product", () => {
    assert.equal(licensePlan(null), licensePlans[0]);
    assert.equal(licensePlan("pdt_attacker"), undefined);
    assert.equal(licensePlan(""), undefined);
  });
});

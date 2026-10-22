import assert from "node:assert/strict";
import { describe, test } from "node:test";
import { withoutPaymentDetails } from "./analytics.ts";

describe("withoutPaymentDetails", () => {
  test("drops the payment ID from the purchase page", () => {
    const event = withoutPaymentDetails({
      type: "pageview",
      url: "https://localbolo.app/purchase?payment_id=pay_123&status=succeeded",
    });

    assert.deepEqual(event, { type: "pageview", url: "https://localbolo.app/purchase" });
  });

  test("leaves other pages alone, query string included", () => {
    const event = { type: "pageview" as const, url: "https://localbolo.app/support?ref=twitter#lost-key" };

    assert.equal(withoutPaymentDetails(event), event);
  });

  test("only matches the purchase page itself", () => {
    const event = { type: "pageview" as const, url: "https://localbolo.app/purchases-faq?payment_id=x" };

    assert.equal(withoutPaymentDetails(event), event);
  });
});

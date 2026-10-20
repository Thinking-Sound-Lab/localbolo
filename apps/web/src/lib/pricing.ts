/** One license key per purchase; the selected plan sets its Mac activation limit. */
export const licensePlans = [
  { id: "single", name: "1 Mac", macs: 1, price: 49, label: "$49", originalPrice: 69, originalLabel: "$69", productEnv: "DODO_PAYMENTS_PRODUCT_ID" },
  { id: "duo", name: "2 Macs", macs: 2, price: 99, label: "$99", originalPrice: 159, originalLabel: "$159", productEnv: "DODO_PAYMENTS_TWO_MAC_PRODUCT_ID" },
  { id: "team", name: "5 Macs", macs: 5, price: 299, label: "$299", originalPrice: 399, originalLabel: "$399", productEnv: "DODO_PAYMENTS_FIVE_MAC_PRODUCT_ID" },
] as const;

export type LicensePlan = (typeof licensePlans)[number];

export function licensePlan(id: string | null): LicensePlan | undefined {
  return id === null ? licensePlans[0] : licensePlans.find((plan) => plan.id === id);
}

export function purchaseUrl(plan: LicensePlan) {
  return `/buy?plan=${plan.id}`;
}

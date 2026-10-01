"use client";

import { Analytics as VercelAnalytics } from "@vercel/analytics/next";
import { withoutPaymentDetails } from "@/lib/analytics";

/** Vercel Web Analytics: anonymous page views, with no cookies and no payment IDs. */
export function Analytics() {
  return <VercelAnalytics beforeSend={withoutPaymentDetails} />;
}

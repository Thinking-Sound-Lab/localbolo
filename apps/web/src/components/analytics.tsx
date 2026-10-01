"use client";

import { Analytics as VercelAnalytics, type BeforeSendEvent } from "@vercel/analytics/next";

/**
 * Vercel Web Analytics: anonymous page views, with no cookies. The purchase
 * page's address carries the buyer's payment ID, so it's sent without its
 * query string.
 */
export function Analytics() {
  return <VercelAnalytics beforeSend={withoutPaymentDetails} />;
}

function withoutPaymentDetails(event: BeforeSendEvent): BeforeSendEvent {
  const url = new URL(event.url);
  if (url.pathname !== "/purchase") return event;
  url.search = "";
  return { ...event, url: url.toString() };
}

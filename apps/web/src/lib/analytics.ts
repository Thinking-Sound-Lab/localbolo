import type { BeforeSendEvent } from "@vercel/analytics/next";

/**
 * Removes what analytics must never see before a page view is sent. The
 * purchase page's address carries the buyer's payment ID, so it goes without
 * its query string.
 */
export function withoutPaymentDetails(event: BeforeSendEvent): BeforeSendEvent {
  const url = new URL(event.url);
  if (url.pathname !== "/purchase") return event;
  url.search = "";
  return { ...event, url: url.toString() };
}

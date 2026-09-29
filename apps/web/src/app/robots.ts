import type { MetadataRoute } from "next";
import { site } from "@/lib/site";

export default function robots(): MetadataRoute.Robots {
  return {
    // Checkout, receipts, downloads and the app's update feed aren't pages, so keep crawlers out.
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: ["/buy", "/purchase", "/download", "/appcast.xml", "/api/"],
    },
    sitemap: `${site.url}/sitemap.xml`,
  };
}

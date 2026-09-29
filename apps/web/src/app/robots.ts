import type { MetadataRoute } from "next";
import { site } from "@/lib/site";

export default function robots(): MetadataRoute.Robots {
  return {
    // /buy starts a checkout and /purchase is a buyer's receipt, so keep crawlers out.
    rules: { userAgent: "*", allow: "/", disallow: ["/buy", "/purchase", "/api/"] },
    sitemap: `${site.url}/sitemap.xml`,
  };
}

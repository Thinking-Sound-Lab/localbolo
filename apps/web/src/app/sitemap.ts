import type { MetadataRoute } from "next";
import { site } from "@/lib/site";

/**
 * Every page on the site. Add new pages here so search engines find them.
 * There's no `lastModified`: the build time would claim every page changed on
 * every deploy, and crawlers learn to ignore dates that aren't accurate.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: site.url, changeFrequency: "monthly", priority: 1 },
    { url: `${site.url}/support`, changeFrequency: "monthly", priority: 0.6 },
    { url: `${site.url}/changelog`, changeFrequency: "monthly", priority: 0.5 },
    { url: `${site.url}/privacy`, changeFrequency: "yearly", priority: 0.4 },
    { url: `${site.url}/terms`, changeFrequency: "yearly", priority: 0.3 },
    { url: `${site.url}/refunds`, changeFrequency: "yearly", priority: 0.3 },
  ];
}

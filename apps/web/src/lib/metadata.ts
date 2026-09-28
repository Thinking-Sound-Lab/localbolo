import type { Metadata } from "next";
import { site } from "@/lib/site";

const homeTitle = `${site.name}: ${site.tagline}`;

/** The link preview image, drawn by app/opengraph-image.tsx. */
const previewImage = { url: "/opengraph-image", width: 1200, height: 630, alt: homeTitle };

/**
 * Metadata for a page: its canonical URL and matching link previews.
 *
 * Next replaces nested fields like `openGraph` wholesale rather than merging
 * them with the layout's, so every page sets them all here. Leave out
 * `title` for the home page; other titles get the site name appended.
 */
export function pageMetadata({
  path,
  title,
  description = site.description,
}: {
  path: string;
  title?: string;
  description?: string;
}): Metadata {
  const fullTitle = title ? `${title} · ${site.name}` : homeTitle;

  return {
    title: { absolute: fullTitle },
    description,
    alternates: { canonical: path },
    openGraph: {
      type: "website",
      url: path,
      siteName: site.name,
      locale: "en_US",
      title: fullTitle,
      description,
      images: previewImage,
    },
    twitter: {
      card: "summary_large_image",
      title: fullTitle,
      description,
      images: previewImage,
    },
  };
}

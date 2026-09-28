import { faq } from "@/lib/faq";
import { site } from "@/lib/site";

/**
 * schema.org data for the home page, published as JSON-LD: who makes
 * LocalBolo, what it is and costs, and the answers from the FAQ.
 */
export function homePageStructuredData() {
  const organization = { "@id": `${site.url}/#organization` };

  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        ...organization,
        name: site.company,
        url: site.url,
        logo: `${site.url}/app-icon.png`,
      },
      {
        "@type": "WebSite",
        "@id": `${site.url}/#website`,
        name: site.name,
        url: site.url,
        description: site.description,
        inLanguage: "en",
        publisher: organization,
      },
      {
        "@type": "SoftwareApplication",
        "@id": `${site.url}/#app`,
        name: site.name,
        description: site.description,
        url: site.url,
        image: `${site.url}/app-icon.png`,
        applicationCategory: "UtilitiesApplication",
        operatingSystem: "macOS 15 or later",
        processorRequirements: "Apple Silicon (M1 or later)",
        featureList: [
          "Hold fn to dictate into any app",
          "Speech recognition that runs entirely on your Mac",
          "Works offline after downloading a model",
          "Optional on-device cleanup of filler words and self-corrections",
          "Parakeet and Whisper speech models",
        ],
        publisher: organization,
        offers: {
          "@type": "Offer",
          price: site.price.amount.toFixed(2),
          priceCurrency: site.price.currency,
          url: `${site.url}/#pricing`,
          availability: "https://schema.org/InStock",
        },
      },
      {
        "@type": "FAQPage",
        "@id": `${site.url}/#faq`,
        mainEntity: faq.map((item) => ({
          "@type": "Question",
          name: item.question,
          acceptedAnswer: { "@type": "Answer", text: item.answer },
        })),
      },
    ],
  };
}

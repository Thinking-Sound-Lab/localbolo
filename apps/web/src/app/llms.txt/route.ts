import { faq } from "@/lib/faq";
import { speechModels } from "@/lib/models";
import { site } from "@/lib/site";

export const dynamic = "force-static";

/**
 * A plain-text summary of the site for AI assistants and answer engines,
 * following the llms.txt convention (https://llmstxt.org).
 */
export function GET() {
  const text = `# ${site.name}

> ${site.description}

${site.name} is a dictation app for Mac. Hold the fn key, speak, and let go: your words are transcribed by a speech model running on your Mac and pasted at your cursor in any app. Audio never leaves the device.

- Price: ${site.price.label} (${site.price.currency}), one-time purchase
- Requirements: ${site.requirements}
- Speech models: ${speechModels.map((model) => `${model.name} (${model.megabytes} MB)`).join(", ")}
- Optional transcript cleanup with an on-device language model (Qwen 2.5 1.5B)
- Made by ${site.company}

## Pages

- [Home](${site.url}/): what ${site.name} does, how it works, models, pricing, and FAQ
- [Privacy](${site.url}/privacy): exactly what the app does with your data

## FAQ

${faq.map((item) => `### ${item.question}\n\n${item.answer}`).join("\n\n")}
`;

  return new Response(text, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}

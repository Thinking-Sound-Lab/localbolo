/** Site-wide copy and links, kept in one place so pages stay consistent. */
export const site = {
  name: "LocalBolo",
  tagline: "Private voice dictation for Mac",
  description:
    "Hold fn, speak, and let go. LocalBolo turns your voice into text in any app, using speech models that run entirely on your Mac.",
  /** Base URL for absolute links such as link previews. Set per environment in .env.development / .env.production. */
  url: process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000",
  repositoryUrl: "https://github.com/Thinking-Sound-Lab/localbolo",
  downloadUrl: "https://github.com/Thinking-Sound-Lab/localbolo/releases/latest",
  requirements: "macOS 15 or later · Apple Silicon",
} as const;

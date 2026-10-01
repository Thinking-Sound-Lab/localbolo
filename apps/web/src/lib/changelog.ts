import { site } from "@/lib/site";

/**
 * Every release of the Mac app, newest first, written for the people who use
 * it. The website's changelog and the app's update window both show these, so
 * write them with .claude/skills/release-notes/SKILL.md. `version` is the
 * release tag without the v, such as "0.2.1".
 */
export const releases: { version: string; date: string; changes: string[] }[] = [
  {
    version: "0.2.1",
    date: "October 1, 2026",
    changes: [
      "LocalBolo's website is now localbolo.app. The app's links and update checks use the new address.",
    ],
  },
  {
    version: "0.2.0",
    date: "September 30, 2026",
    changes: [
      "LocalBolo asks for your license key the first time it opens, then walks you through permissions.",
      `Each key works on up to ${site.macsPerLicense} Macs. Settings › License shows your key and frees this Mac for another one.`,
      "LocalBolo now updates itself. It checks for new versions once a day, and Check for Updates… is in the menu bar. If you have 0.1, download 0.2 once; it takes care of updates from then on.",
      "A new app icon and menu bar icon.",
    ],
  },
  {
    version: "0.1.0",
    date: "September 28, 2026",
    changes: [
      "Hold fn anywhere to dictate, and let go to paste the text at your cursor.",
      "The pill shows the icon of the app your words will land in, with a live waveform.",
      "NVIDIA Parakeet v2 as the default speech model, plus Whisper Base, Small and Large v3 Turbo.",
      "Optional transcript cleanup with Qwen 2.5 1.5B, running on your Mac, which applies your self-corrections and removes filler words.",
      "Your clipboard is restored after every paste.",
      "Copy Last Transcript from the menu bar.",
      "A setup guide for the microphone, Accessibility and the fn key.",
      "Launch at login.",
    ],
  },
];

/** The newest release, for the hero's badge when GitHub's releases can't be read. */
export const latestRelease = releases[0];

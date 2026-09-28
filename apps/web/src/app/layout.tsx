import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono, Geist_Pixel } from "next/font/google";
import { site } from "@/lib/site";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

// Square pixels, the font's default shape. Next has no metrics to size a
// fallback for this font, so it falls back to mono.
const geistPixel = Geist_Pixel({
  variable: "--font-geist-pixel",
  subsets: ["latin"],
  adjustFontFallback: false,
  fallback: ["ui-monospace", "monospace"],
});

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: {
    default: `${site.name}: ${site.tagline}`,
    template: `%s · ${site.name}`,
  },
  description: site.description,
  applicationName: site.name,
  keywords: [
    "dictation app for Mac",
    "offline dictation",
    "private dictation",
    "speech to text for Mac",
    "voice typing",
    "on-device transcription",
    "Parakeet",
    "Whisper",
  ],
  authors: [{ name: site.company }],
  creator: site.company,
  publisher: site.company,
  category: "technology",
};

export const viewport: Viewport = {
  themeColor: "#ffffff",
  colorScheme: "light",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} ${geistPixel.variable} antialiased`}
    >
      {/* "Back to top" links point here. */}
      <body id="top" className="min-h-full font-sans">
        {children}
      </body>
    </html>
  );
}

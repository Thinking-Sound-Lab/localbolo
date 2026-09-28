import { PixelArt } from "@/components/pixel-art";
import { cx } from "@/lib/cx";
import { pixelIcons } from "@/lib/pixel-icons";
import type { PixelArtRows } from "@/lib/pixels";

/** A generic app icon for the product demo: a pixel glyph on a rounded tile. */
function AppTile({ art, className }: { art: PixelArtRows; className: string }) {
  return (
    <div className={cx("grid size-full place-items-center rounded-[24%] ring-1 ring-inset", className)}>
      <PixelArt art={art} className="w-[62%]" />
    </div>
  );
}

export function MailIcon() {
  return <AppTile art={pixelIcons.mail} className="bg-blue text-white ring-white/25" />;
}

export function ChatIcon() {
  return <AppTile art={pixelIcons.chat} className="bg-white text-ink ring-ink/10" />;
}

export function NotesIcon() {
  return <AppTile art={pixelIcons.notes} className="bg-white text-blue ring-ink/10" />;
}

export function TerminalIcon() {
  return <AppTile art={pixelIcons.terminal} className="bg-ink text-white ring-white/25" />;
}

export function BrowserIcon() {
  return <AppTile art={pixelIcons.globe} className="bg-blue-pale text-blue ring-ink/10" />;
}

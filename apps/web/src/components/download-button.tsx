import { site } from "@/lib/site";
import { cx } from "@/lib/cx";

const sizes = {
  sm: "px-4 py-2 text-sm",
  lg: "px-6 py-3.5 text-base",
};

export function DownloadButton({
  size = "lg",
  className,
}: {
  size?: keyof typeof sizes;
  className?: string;
}) {
  return (
    <a
      href={site.downloadUrl}
      className={cx(
        "group inline-flex items-center gap-2 rounded-full bg-ink font-medium text-paper shadow-[0_8px_20px_-8px_rgba(0,0,0,0.5)] transition hover:bg-black focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink",
        sizes[size],
        className,
      )}
    >
      <svg
        viewBox="0 0 24 24"
        className="size-4 fill-none stroke-current stroke-2 [stroke-linecap:round] [stroke-linejoin:round] transition-transform group-hover:translate-y-0.5"
        aria-hidden
      >
        <path d="M12 4v11m0 0-4.5-4.5M12 15l4.5-4.5M5 20h14" />
      </svg>
      Download for Mac
    </a>
  );
}

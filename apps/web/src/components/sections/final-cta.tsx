import { ChatIcon } from "@/components/app-icons";
import { DownloadButton } from "@/components/download-button";
import { Pill } from "@/components/pill";
import { site } from "@/lib/site";

export function FinalCta() {
  return (
    <section className="border-t border-line bg-paper-deep/60">
      <div className="mx-auto flex max-w-6xl flex-col items-center px-6 py-24 text-center sm:py-32">
        <Pill state="listening" icon={<ChatIcon />} />
        <h2 className="mt-10 font-display text-5xl leading-[1.02] tracking-tight sm:text-7xl">
          Give your keyboard a break.
        </h2>
        <p className="mt-5 max-w-md text-lg text-ink-soft">
          Setup takes a minute. After that, it&apos;s just you, the fn key, and your voice.
        </p>
        <DownloadButton className="mt-9" />
        <p className="mt-4 text-sm text-ink-faint">{site.requirements}</p>
      </div>
    </section>
  );
}

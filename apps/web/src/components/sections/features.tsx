import { SectionHeading } from "@/components/sections/section-heading";

const features = [
  {
    title: "On-device, always",
    body: "Speech models run on the Neural Engine in your Mac. There is no server to send audio to.",
    icon: "M12 3 4 6v6c0 4.5 3.4 8.2 8 9 4.6-.8 8-4.5 8-9V6l-8-3Z",
  },
  {
    title: "Works in every app",
    body: "Mail, Slack, your code editor, a browser tab. Anywhere there's a cursor, your words land there.",
    icon: "M4 5h16v11H4zM8 20h8M12 16v4",
  },
  {
    title: "Knows where it's typing",
    body: "The pill shows the icon of the app that will receive your text, so you never paste into the wrong window.",
    icon: "M4 12a8 8 0 1 0 16 0 8 8 0 0 0-16 0Zm8-3v3l2 2",
  },
  {
    title: "Fast on Apple Silicon",
    body: "Parakeet transcribes a sentence in a fraction of a second, even on the first M1 Macs.",
    icon: "M13 3 5 13h6l-1 8 8-10h-6l1-8Z",
  },
  {
    title: "Built for English",
    body: "English-first models handle punctuation, capitalization, and everyday names without extra setup.",
    icon: "M4 6h10M9 6v12M14 18l4-10 4 10M15.5 14h5",
  },
  {
    title: "Fixes it when you correct yourself",
    body: "Say “3 p.m., sorry, 4 p.m.” and only “4 p.m.” lands. An optional on-device language model applies your corrections and drops the ums.",
    icon: "M4 20l4-1 11-11-3-3L5 16l-1 4ZM14 7l3 3",
  },
];

export function Features() {
  return (
    <section className="border-t border-line bg-paper-deep/40">
      <div className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
        <SectionHeading eyebrow="Why LocalBolo" title="Built to disappear into your day." />

        <div className="mt-14 grid gap-x-10 gap-y-12 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((feature) => (
            <div key={feature.title}>
              <div className="grid size-11 place-items-center rounded-xl bg-ink text-paper">
                <svg
                  viewBox="0 0 24 24"
                  className="size-5 fill-none stroke-current stroke-[1.8] [stroke-linecap:round] [stroke-linejoin:round]"
                  aria-hidden
                >
                  <path d={feature.icon} />
                </svg>
              </div>
              <h3 className="mt-5 text-lg font-semibold tracking-tight">{feature.title}</h3>
              <p className="mt-2 text-ink-soft">{feature.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

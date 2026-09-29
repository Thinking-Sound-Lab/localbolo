import {
  siClaude,
  siCursor,
  siDiscord,
  siGmail,
  siGooglechrome,
  siGoogledocs,
  siImessage,
  siLinear,
  siNotion,
  siObsidian,
  siWhatsapp,
  siXcode,
  type SimpleIcon,
} from "simple-icons";

/**
 * Apps people dictate into most, with their logos from Simple Icons.
 * LocalBolo pastes into any text field, so these are only examples.
 */
const apps: SimpleIcon[] = [
  siGmail,
  siImessage,
  siWhatsapp,
  siDiscord,
  siNotion,
  siGoogledocs,
  siObsidian,
  siLinear,
  siClaude,
  siCursor,
  siXcode,
  siGooglechrome,
];

export function WorksEverywhere() {
  return (
    <section aria-labelledby="works-everywhere" className="bg-ink text-white">
      <div className="mx-auto max-w-6xl px-6 py-12">
        <h2
          id="works-everywhere"
          className="text-center font-mono text-[11px] tracking-[0.14em] text-white/55 uppercase"
        >
          Works wherever you can type
        </h2>
        <ul className="mt-8 grid grid-cols-3 border-t border-l border-white/10 sm:grid-cols-4 lg:grid-cols-6">
          {apps.map((app) => (
            <li
              key={app.slug}
              className="flex h-28 flex-col items-center justify-center gap-3 border-r border-b border-white/10 px-2"
            >
              <svg viewBox="0 0 24 24" aria-hidden className="size-7 fill-white/85">
                <path d={app.path} />
              </svg>
              <span className="font-mono text-[11px] tracking-wide text-white/55">{app.title}</span>
            </li>
          ))}
        </ul>
        <p className="mt-6 text-center text-sm text-white/55">
          …and every other app with a text field.
        </p>
      </div>
    </section>
  );
}

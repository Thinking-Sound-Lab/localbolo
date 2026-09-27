const places = ["Email", "Chat", "Docs", "Notes", "Code editors", "Browsers", "Terminals"];

export function WorksEverywhere() {
  return (
    <section className="border-y border-line bg-paper-deep/60">
      <div className="mx-auto flex max-w-6xl flex-col items-center gap-6 px-6 py-10 md:flex-row md:justify-between">
        <p className="text-center font-display text-3xl tracking-tight text-balance md:text-left">If you can type in it, you can talk to it.</p>
        <ul className="flex flex-wrap justify-center gap-2">
          {places.map((place) => (
            <li
              key={place}
              className="rounded-full border border-line bg-white/70 px-3.5 py-1.5 text-sm text-ink-soft"
            >
              {place}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

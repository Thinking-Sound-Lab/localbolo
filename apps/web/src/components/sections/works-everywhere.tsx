const places = ["Email", "Chat", "Docs", "Notes", "Code editors", "Browsers", "Terminals"];

export function WorksEverywhere() {
  return (
    <section className="border-y border-line">
      <div className="mx-auto flex max-w-6xl flex-col items-center gap-6 px-6 py-10 md:flex-row md:justify-between">
        <p className="text-center text-2xl font-medium tracking-[-0.03em] text-balance md:text-left">
          If you can type in it, you can talk to it.
        </p>
        <ul className="flex flex-wrap justify-center gap-x-5 gap-y-2 font-mono text-xs tracking-wide text-ink-soft uppercase">
          {places.map((place) => (
            <li key={place} className="flex items-center gap-2">
              <span aria-hidden className="size-1.5 bg-ink" />
              {place}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

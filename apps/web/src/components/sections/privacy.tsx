const facts = [
  {
    title: "No servers",
    body: "There is no LocalBolo cloud. Audio is transcribed by a model running on your Mac.",
  },
  {
    title: "No account",
    body: "Download it, allow microphone and accessibility access, and start talking.",
  },
  {
    title: "Nothing is kept",
    body: "Recordings live in memory only while they're transcribed, then they're gone.",
  },
  {
    title: "Only listens on fn",
    body: "The microphone turns on when you hold fn and turns off the moment you let go.",
  },
];

export function Privacy() {
  return (
    <section id="privacy" className="scroll-mt-16 bg-ink text-paper">
      <div className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
        <p className="text-sm font-medium tracking-wide text-ember uppercase">Privacy</p>
        <h2 className="mt-3 max-w-3xl font-display text-5xl leading-[1.02] tracking-tight sm:text-7xl">
          Your voice stays yours. <span className="text-paper/50 italic">Full stop.</span>
        </h2>

        <div className="mt-16 grid gap-px overflow-hidden rounded-3xl bg-white/10 sm:grid-cols-2 lg:grid-cols-4">
          {facts.map((fact) => (
            <div key={fact.title} className="bg-ink p-6 sm:p-7">
              <h3 className="text-lg font-semibold tracking-tight">{fact.title}</h3>
              <p className="mt-2 text-paper/65">{fact.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

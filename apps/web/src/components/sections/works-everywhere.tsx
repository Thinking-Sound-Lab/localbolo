/** Apps people dictate into most. LocalBolo pastes into any text field, so these are examples. */
const apps = ["Mail", "Messages", "Slack", "Notion", "Google Docs", "Cursor", "Xcode", "Terminal"];

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
        <ul className="mt-8 grid grid-cols-2 border-t border-l border-white/10 sm:grid-cols-4 lg:grid-cols-8">
          {apps.map((app) => (
            <li
              key={app}
              className="grid h-20 place-items-center border-r border-b border-white/10 px-2 text-center font-pixel text-lg text-white/85"
            >
              {app}
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

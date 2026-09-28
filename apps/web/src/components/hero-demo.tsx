"use client";

import { useEffect, useState, type ReactNode } from "react";
import { BrowserIcon, ChatIcon, MailIcon, NotesIcon, TerminalIcon } from "@/components/app-icons";
import { FnKey } from "@/components/fn-key";
import { Logo } from "@/components/logo";
import { Pill, type PillState } from "@/components/pill";
import { usePrefersReducedMotion } from "@/lib/use-prefers-reduced-motion";

type Scene = {
  app: string;
  icon: ReactNode;
  /** Chat apps type into a message box; documents type into the page itself. */
  layout: "document" | "chat";
  context: ReactNode;
  /** What the speaker says, fillers and corrections included. */
  spoken: string;
  /** What lands in the text field after cleanup. */
  transcript: string;
};

const scenes: Scene[] = [
  {
    app: "Mail",
    icon: <MailIcon />,
    layout: "document",
    context: (
      <>
        <Field label="To">Priya Sharma</Field>
        <Field label="Subject">Moving our call</Field>
      </>
    ),
    spoken: "Hi Priya, can we move our call to 3 p.m., sorry, 4 p.m. tomorrow?",
    transcript: "Hi Priya, can we move our call to 4 p.m. tomorrow?",
  },
  {
    app: "Chat",
    icon: <ChatIcon />,
    layout: "chat",
    context: (
      <>
        <Message name="Sam">Did the login fix make it into today&apos;s build?</Message>
        <Message name="Alex">I think so, can someone confirm?</Message>
      </>
    ),
    spoken: "Yes, it, um, shipped this morning. I tested it on Safari and Chrome and both look good.",
    transcript: "Yes, it shipped this morning. I tested it on Safari and Chrome and both look good.",
  },
  {
    app: "Notes",
    icon: <NotesIcon />,
    layout: "document",
    context: <p className="text-lg font-semibold tracking-tight text-ink">Team offsite ideas</p>,
    spoken: "A morning hike, a short demo day after lunch, and, uh, dinner somewhere with a view of the the water.",
    transcript:
      "A morning hike, a short demo day after lunch, and dinner somewhere with a view of the water.",
  },
];

/** How long each step of a scene stays on screen, in milliseconds. */
const timeline: { phase: Phase; duration: number }[] = [
  { phase: "waiting", duration: 1300 },
  { phase: "listening", duration: 2600 },
  { phase: "transcribing", duration: 800 },
  { phase: "pasted", duration: 2800 },
];

type Phase = "waiting" | "listening" | "transcribing" | "pasted";

/**
 * An animated re-creation of dictating on a Mac: hold fn, the pill shows the
 * target app and listens, then the cleaned-up transcript lands in the text field.
 */
export function HeroDemo() {
  const [sceneIndex, setSceneIndex] = useState(0);
  const [step, setStep] = useState(0);
  const prefersReducedMotion = usePrefersReducedMotion();

  useEffect(() => {
    if (prefersReducedMotion) return;
    const timer = setTimeout(() => {
      if (step === timeline.length - 1) {
        setStep(0);
        setSceneIndex((index) => (index + 1) % scenes.length);
      } else {
        setStep(step + 1);
      }
    }, timeline[step].duration);
    return () => clearTimeout(timer);
  }, [step, prefersReducedMotion]);

  const scene = scenes[sceneIndex];
  const phase: Phase = prefersReducedMotion ? "pasted" : timeline[step].phase;
  const pillState: PillState =
    phase === "listening" ? "listening" : phase === "transcribing" ? "transcribing" : "resting";

  return (
    <div className="relative mx-auto aspect-[4/5] w-full max-w-5xl overflow-hidden rounded-[20px] bg-blue shadow-[0_40px_80px_-32px_rgba(10,10,10,0.55)] ring-1 ring-ink/10 dot-grid [--dot-color:rgb(255_255_255/0.2)] sm:aspect-[16/10]">
      <MenuBar />

      {/* App window */}
      <div className="absolute inset-x-[6%] top-[11%] bottom-[23%] flex flex-col overflow-hidden rounded-lg bg-white shadow-[0_24px_60px_-20px_rgba(0,0,0,0.5)] sm:inset-x-[14%] sm:bottom-[20%]">
        <div className="flex items-center gap-2 border-b border-ink/10 px-4 py-3">
          <span className="size-3 rounded-full bg-ink/15" />
          <span className="size-3 rounded-full bg-ink/15" />
          <span className="size-3 rounded-full bg-ink/15" />
          <div className="ml-3 flex items-center gap-2 font-mono text-xs text-ink-soft">
            <span className="size-4">{scene.icon}</span>
            {scene.app}
          </div>
        </div>

        <div key={sceneIndex} className="flex flex-1 flex-col gap-3 p-5 text-left sm:p-7">
          {scene.context}
          <p
            className={
              scene.layout === "chat"
                ? "mt-auto min-h-20 rounded-md border border-ink/15 bg-white p-3 text-[15px] leading-relaxed text-ink sm:text-base"
                : "pt-1 text-[15px] leading-relaxed text-ink sm:text-base"
            }
          >
            {phase === "pasted" ? <span className="animate-fade-in">{scene.transcript}</span> : null}
            <span className="ml-px inline-block h-[1.1em] w-[2px] translate-y-[3px] motion-safe:animate-blink bg-blue" />
          </p>
        </div>
      </div>

      {/* Pill above the Dock, with a caption of what's being said */}
      <div className="absolute inset-x-0 bottom-[12.5%] flex flex-col items-center gap-2 px-6">
        <p
          aria-hidden={phase !== "listening"}
          className={`max-w-md rounded-md bg-ink px-3 py-1.5 text-center text-xs text-white transition-opacity duration-300 sm:text-sm ${
            phase === "listening" ? "opacity-100" : "opacity-0"
          }`}
        >
          “{scene.spoken}”
        </p>
        <Pill state={pillState} icon={scene.icon} />
      </div>

      <Dock />

      <div className="absolute bottom-[4.5%] left-[4%] hidden sm:block">
        <FnKey isPressed={phase === "listening"} />
      </div>
    </div>
  );
}

function MenuBar() {
  return (
    <div className="absolute inset-x-0 top-0 flex h-7 items-center justify-end gap-4 bg-white/10 px-4 font-mono text-xs text-white/85 backdrop-blur-md">
      <Logo className="h-[14px] w-[18px] text-white" accentClassName="fill-white" />
      <span>Mon 9:41</span>
    </div>
  );
}

const dockIcons = [
  { app: "Mail", Icon: MailIcon },
  { app: "Chat", Icon: ChatIcon },
  { app: "Notes", Icon: NotesIcon },
  { app: "Terminal", Icon: TerminalIcon },
  { app: "Browser", Icon: BrowserIcon },
];

function Dock() {
  return (
    <div className="absolute inset-x-0 bottom-[2.5%] flex justify-center">
      <div className="flex gap-2 rounded-2xl border border-white/30 bg-white/15 p-1.5 backdrop-blur-xl sm:gap-2.5 sm:p-2">
        {dockIcons.map(({ app, Icon }) => (
          <div key={app} className="size-7 sm:size-10">
            <Icon />
          </div>
        ))}
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex gap-3 border-b border-ink/10 pb-2 text-sm">
      <span className="w-16 font-mono text-xs leading-5 text-ink-faint">{label}</span>
      <span className="text-ink">{children}</span>
    </div>
  );
}

function Message({ name, children }: { name: string; children: ReactNode }) {
  return (
    <div className="text-sm">
      <span className="font-semibold text-ink">{name}</span>
      <p className="mt-0.5 text-ink-soft">{children}</p>
    </div>
  );
}

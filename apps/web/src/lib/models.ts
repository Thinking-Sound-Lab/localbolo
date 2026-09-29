/**
 * The speech models offered in the app. Keep in sync with
 * apps/mac/LocalBolo/Transcription/SpeechModel.swift.
 */
export type SpeechModel = {
  name: string;
  engine: string;
  /** Download size. */
  megabytes: number;
  summary: string;
  recommended?: boolean;
};

export const speechModels: SpeechModel[] = [
  {
    name: "Parakeet v2",
    engine: "NVIDIA Parakeet",
    megabytes: 470,
    summary: "Best for English. Very fast and highly accurate.",
    recommended: true,
  },
  {
    name: "Whisper Base",
    engine: "OpenAI Whisper",
    megabytes: 150,
    summary: "Smallest download. Good for quick notes.",
  },
  {
    name: "Whisper Small",
    engine: "OpenAI Whisper",
    megabytes: 220,
    summary: "A balance of speed and accuracy.",
  },
  {
    name: "Whisper Large v3 Turbo",
    engine: "OpenAI Whisper",
    megabytes: 630,
    summary: "Most accurate Whisper. Slower on older Macs.",
  },
];

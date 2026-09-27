/**
 * The speech models offered in the app. Keep in sync with
 * apps/mac/LocalBolo/Transcription/SpeechModel.swift.
 */
export type SpeechModel = {
  name: string;
  engine: string;
  size: string;
  summary: string;
  recommended?: boolean;
};

export const speechModels: SpeechModel[] = [
  {
    name: "Parakeet v2",
    engine: "NVIDIA Parakeet",
    size: "470 MB",
    summary: "Best for English. Very fast and highly accurate.",
    recommended: true,
  },
  {
    name: "Whisper Base",
    engine: "OpenAI Whisper",
    size: "150 MB",
    summary: "Smallest download. Good for quick notes.",
  },
  {
    name: "Whisper Small",
    engine: "OpenAI Whisper",
    size: "220 MB",
    summary: "A balance of speed and accuracy.",
  },
  {
    name: "Whisper Large v3 Turbo",
    engine: "OpenAI Whisper",
    size: "630 MB",
    summary: "Most accurate Whisper. Slower on older Macs.",
  },
];

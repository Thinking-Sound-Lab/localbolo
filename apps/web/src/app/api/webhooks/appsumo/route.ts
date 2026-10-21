import { handleAppSumoWebhook } from "@/lib/appsumo-handlers";

export const runtime = "nodejs";
export async function POST(request: Request) {
  return handleAppSumoWebhook(request);
}

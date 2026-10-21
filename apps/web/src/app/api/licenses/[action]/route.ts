import { handleAppSumoLicense } from "@/lib/appsumo-handlers";

export const runtime = "nodejs";
export async function POST(request: Request, { params }: RouteContext<"/api/licenses/[action]">) {
  return handleAppSumoLicense(request, (await params).action);
}

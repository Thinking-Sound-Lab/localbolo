import { appSumoForm, appSumoRedirect, clearAppSumoCookie } from "@/lib/appsumo-forms";
import { appSumoFailure } from "@/lib/appsumo-handlers";

export async function POST(request: Request) {
  try {
    await appSumoForm(request, "session");
    const response = appSumoRedirect();
    clearAppSumoCookie(response, "session");
    return response;
  } catch (error) { return appSumoFailure(error); }
}

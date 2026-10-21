import { appSumoForm, appSumoFormFailure, appSumoRedirect, clearAppSumoCookie } from "@/lib/appsumo-forms";

export async function POST(request: Request) {
  try {
    await appSumoForm(request, "session");
    const response = appSumoRedirect();
    clearAppSumoCookie(response, "session");
    return response;
  } catch (error) { return appSumoFormFailure(error, "session"); }
}

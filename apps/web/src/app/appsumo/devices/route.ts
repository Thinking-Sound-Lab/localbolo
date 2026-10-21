import { AppSumoError, uuidPattern } from "@/lib/appsumo";
import { appSumoForm, appSumoFormFailure, appSumoRedirect } from "@/lib/appsumo-forms";
import { appSumoRPC } from "@/lib/appsumo-store";

export const runtime = "nodejs";
export async function POST(request: Request) {
  let confirmed = false;
  try {
    const { form, state } = await appSumoForm(request, "session");
    confirmed = true;
    const instance = form.get("instance") ?? "";
    if (typeof state.licenseId !== "string" || !uuidPattern.test(state.licenseId) || !uuidPattern.test(instance)) throw new AppSumoError(400, "invalid");
    await appSumoRPC("appsumo_release_device", { p_id: state.licenseId, p_instance: instance });
    return appSumoRedirect();
  } catch (error) { return confirmed ? appSumoRedirect("unavailable") : appSumoFormFailure(error, "session"); }
}

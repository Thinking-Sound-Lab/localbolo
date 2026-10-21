import {
  AppSumoError, appSumoHeaders, appSumoRateBucket, getAppSumoLicense,
  parseAppSumoEvent, productKeyPattern, readSmallBody, uuidPattern, verifyAppSumoSignature,
} from "./appsumo.ts";
import { appSumoRPC, appSumoRateLimit } from "./appsumo-store.ts";

type Dependencies = {
  rpc: typeof appSumoRPC;
  rateLimit: typeof appSumoRateLimit;
  license: typeof getAppSumoLicense;
};
const defaults: Dependencies = { rpc: appSumoRPC, rateLimit: appSumoRateLimit, license: getAppSumoLicense };

export function appSumoFailure(error: unknown) {
  const status = error instanceof AppSumoError ? error.status : 503;
  const reason = error instanceof AppSumoError ? error.reason : "unavailable";
  return Response.json({ error: reason }, {
    status, headers: { ...appSumoHeaders, ...(status === 429 ? { "Retry-After": "60" } : {}) },
  });
}

/** Verify the original bytes before parsing; never log payloads or keys. */
export async function handleAppSumoWebhook(request: Request, deps = defaults) {
  try {
    const secret = process.env.APPSUMO_PRIVATE_KEY;
    if (!secret) throw new AppSumoError(503);
    const raw = await readSmallBody(request);
    if (!verifyAppSumoSignature(raw, request.headers.get("x-appsumo-timestamp"), request.headers.get("x-appsumo-signature"), secret)) throw new AppSumoError(401, "invalid");
    let parsed: unknown;
    try { parsed = JSON.parse(raw.toString()); } catch { throw new AppSumoError(400, "invalid"); }
    if (parsed && typeof parsed === "object" && "test" in parsed && parsed.test === true && "event" in parsed &&
        ["purchase", "activate", "upgrade", "downgrade", "deactivate"].includes(parsed.event as string)) {
      return Response.json({ event: parsed.event, success: true }, { headers: appSumoHeaders });
    }
    const event = parseAppSumoEvent(parsed);
    if (!event.test) {
      let allowReactivation = false;
      if (event.event === "activate" && await deps.rpc<boolean>("appsumo_needs_reactivation", { p_key: event.license_key })) {
        // An old activation retry must not undo a refund. AppSumo can also
        // intentionally reactivate a license; verify that with its private API.
        await deps.rateLimit("appsumo-api", 18);
        const current = await deps.license(event.license_key);
        allowReactivation = current.status !== "deactivated" && current.tier === event.tier;
        if (allowReactivation && !await deps.rpc<boolean>("appsumo_reactivation_ready", { p_key: event.license_key })) throw new AppSumoError(503);
      }
      await deps.rpc("appsumo_apply_event", { p_event: event, p_allow_reactivation: allowReactivation });
    }
    return Response.json({ event: event.event, success: true }, { headers: appSumoHeaders });
  } catch (error) { return appSumoFailure(error); }
}

/** Public activation endpoints, compatible with the existing Mac client's API. */
export async function handleAppSumoLicense(request: Request, action: string, deps = defaults) {
  try {
    if (!["activate", "validate", "deactivate"].includes(action)) throw new AppSumoError(404, "invalid");
    await deps.rateLimit(appSumoRateBucket(request, "mac"), 90);
    if (!request.headers.get("content-type")?.startsWith("application/json")) throw new AppSumoError(415, "invalid");
    let body: Record<string, unknown>;
    try { body = JSON.parse((await readSmallBody(request, 4096)).toString()); }
    catch (error) { if (error instanceof AppSumoError) throw error; throw new AppSumoError(400, "invalid"); }
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new AppSumoError(400, "invalid");
    const key = typeof body.license_key === "string" ? body.license_key.trim().toUpperCase() : "";
    if (!productKeyPattern.test(key)) throw new AppSumoError(404, "invalid");
    const args: Record<string, unknown> = { p_key: key, p_action: action };
    if (action === "activate") {
      if (typeof body.device_id !== "string" || !/^[a-f0-9]{64}$/.test(body.device_id) ||
          typeof body.name !== "string" || !body.name.trim() || body.name.length > 120 || /[\u0000-\u001f\u007f]/.test(body.name)) throw new AppSumoError(400, "invalid");
      args.p_device = body.device_id;
      args.p_name = body.name.trim();
    } else {
      if (typeof body.license_key_instance_id !== "string" || !uuidPattern.test(body.license_key_instance_id)) throw new AppSumoError(400, "invalid");
      args.p_instance = body.license_key_instance_id;
    }
    const result = await deps.rpc<{ status: number; id?: string; valid?: boolean; success?: boolean }>("appsumo_license_action", args);
    const { status, ...response } = result;
    return Response.json(response, { status, headers: appSumoHeaders });
  } catch (error) { return appSumoFailure(error); }
}

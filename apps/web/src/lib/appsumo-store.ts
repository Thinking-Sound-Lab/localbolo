import { createClient } from "@supabase/supabase-js";
import type { SupabaseClient } from "@supabase/supabase-js";
import { AppSumoError, type AppSumoProfile } from "./appsumo.ts";

export function appSumoDatabase(): SupabaseClient {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SECRET_KEY;
  if (!url || !key) throw new AppSumoError(503);
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}
export async function appSumoRPC<T>(name: string, args: Record<string, unknown>, db = appSumoDatabase()): Promise<T> {
  const { data, error } = await db.rpc(name, args);
  if (error) {
    // Messages, details, arguments and payloads can contain buyer credentials.
    console.error("AppSumo database request failed", {
      operation: /^appsumo_[a-z_]{1,64}$/.test(name) ? name : "unknown",
      code: /^(?:[A-Z0-9]{5}|PGRST\d{3})$/.test(error.code) ? error.code : "unknown",
    });
    throw new AppSumoError(503);
  }
  return data as T;
}
export async function appSumoProfile(id: string) {
  return appSumoRPC<AppSumoProfile | null>("appsumo_profile", { p_id: id });
}
export async function appSumoRateLimit(bucket: string, limit: number) {
  if (!await appSumoRPC<boolean>("appsumo_rate_limit", { p_bucket: bucket, p_limit: limit })) throw new AppSumoError(429, "limited");
}

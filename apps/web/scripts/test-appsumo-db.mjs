import assert from "node:assert/strict";
import { execFile, execFileSync, spawn } from "node:child_process";
import { readdirSync, readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { promisify } from "node:util";

// Isolated, disposable Postgres; no project secrets or live provider calls.
const exec = promisify(execFile);
const container = `localbolo-licensing-test-${randomUUID().slice(0, 8)}`;
const sql = (input) => execFileSync("docker", ["exec", "-i", container, "psql", "-U", "postgres", "-Atq", "-v", "ON_ERROR_STOP=1"], { input, encoding: "utf8" }).trim();
const parallelSQL = async (query) => (await exec("docker", ["exec", container, "psql", "-U", "postgres", "-Atq", "-v", "ON_ERROR_STOP=1", "-c", query])).stdout.trim();
const waitFor = async (query, expected) => {
  for (let attempt = 0; sql(query) !== expected; attempt++) {
    if (attempt >= 100) throw Error(`Timed out waiting for: ${query}`);
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
};
let started = false;
try {
  execFileSync("docker", ["run", "--rm", "-d", "--name", container, "-e", "POSTGRES_PASSWORD=disposable-local-test", "postgres:17-alpine"], { stdio: "ignore" });
  started = true;
  for (let attempt = 0; ; attempt++) {
    try { execFileSync("docker", ["exec", container, "pg_isready", "-U", "postgres"], { stdio: "ignore" }); break; }
    catch { if (attempt >= 60) throw Error("Test database did not start"); await new Promise((resolve) => setTimeout(resolve, 500)); }
  }
  sql("create role anon; create role authenticated; create role service_role bypassrls;");
  const migrations = new URL("../supabase/migrations/", import.meta.url);
  for (const file of readdirSync(migrations).filter((name) => name.includes("_appsumo_")).sort()) {
    sql(readFileSync(new URL(file, migrations), "utf8"));
  }
  sql(readFileSync(new URL("../supabase/tests/appsumo.sql", import.meta.url), "utf8"));
  console.log("Lifecycle, tiers, aliases, refunds, device ownership, and RLS assertions passed.");
  for (const [tier, macs] of [[1, 1], [2, 2], [3, 5]]) {
    const key = randomUUID();
    sql(`set role service_role; select appsumo_apply_event('{"event":"activate","license_key":"${key}","tier":${tier}}');`);
    const product = JSON.parse(sql(`set role service_role; select appsumo_claim('${key}');`)).product_key;
    const attempts = await Promise.all(Array.from({ length: 12 }, (_, index) => parallelSQL(
      `set role service_role; select appsumo_license_action('${product}','activate',null,'${(index + 1).toString(16).padStart(64, "0")}','Concurrent Mac')->>'status';`
    )));
    assert.equal(attempts.filter((status) => status === "201").length, macs, `Tier ${tier} race must allow exactly ${macs} Macs`);
    assert.equal(attempts.filter((status) => status === "422").length, 12 - macs);
    sql(`select appsumo_apply_event('{"event":"deactivate","license_key":"${key}"}');`);
  }
  console.log("Concurrent activation races passed for all three tiers.");
  const rateAttempts = await Promise.all(Array.from({ length: 40 }, () => parallelSQL(
    "set role service_role; select appsumo_rate_limit('appsumo-api-race',18);"
  )));
  assert.equal(rateAttempts.filter((allowed) => allowed === "t").length, 18);
  console.log("Concurrent rolling rate limit allows exactly 18 requests.");
  // Another request's cleanup deletes this expired bucket while the request waits for it.
  sql("insert into appsumo_rate_limits(bucket, expires_at) values ('appsumo-cleanup-race', now() - interval '1 minute');");
  const cleanup = spawn("docker", ["exec", "-i", container, "psql", "-U", "postgres", "-Atq", "-v", "ON_ERROR_STOP=1"], { stdio: ["pipe", "ignore", "inherit"] });
  const cleanupDone = new Promise((resolve) => cleanup.on("close", resolve));
  cleanup.stdin.write("begin; select 1 from appsumo_rate_limits where bucket = 'appsumo-cleanup-race' for update;\n");
  await waitFor("select count(*) from pg_stat_activity where state = 'idle in transaction'", "1");
  const raced = parallelSQL("set role service_role; select appsumo_rate_limit('appsumo-cleanup-race',1);");
  await waitFor("select count(*) from pg_stat_activity where wait_event_type = 'Lock'", "1");
  cleanup.stdin.end("delete from appsumo_rate_limits where bucket = 'appsumo-cleanup-race'; commit;\n");
  await cleanupDone;
  assert.equal(await raced, "t");
  assert.equal(sql("set role service_role; select appsumo_rate_limit('appsumo-cleanup-race',1);"), "f", "A request must be counted even if cleanup deletes its expired bucket");
  console.log("Rate limit counts requests whose expired bucket is cleaned up concurrently.");
} finally {
  if (started) execFileSync("docker", ["rm", "-f", container], { stdio: "ignore" });
}

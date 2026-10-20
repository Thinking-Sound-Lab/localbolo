import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { exportCodes } from "../../scripts/appsumo-codes.mjs";

function provider() {
  const keys = new Map<string, { id: string; key: string; status: string; activations_limit: number; expires_at: null }>();
  let requests = 0;
  let failAt = 0;
  const client = {
    licenseKeys: {
      create: async (args: { key: string; activations_limit: number; expires_at: null }) => {
        requests++;
        if (requests === failAt) throw Object.assign(new Error("Provider unavailable"), { status: 503 });
        if (keys.has(args.key)) throw Object.assign(new Error("Duplicate"), { status: 409 });
        const record = { id: `lic_${keys.size}`, key: args.key, status: "active", activations_limit: args.activations_limit, expires_at: args.expires_at };
        keys.set(args.key, record);
        return record;
      },
      list: async function* () { yield* keys.values(); },
    },
    licenses: { validate: async () => ({ valid: true }) },
  };
  return { client, keys, failOn: (request: number) => { failAt = request; } };
}

for (const macs of [1, 2, 5]) test(`CSV contains only registered, distinct, ${macs}-Mac keys and has a header`, async () => {
  const dir = await mkdtemp(join(tmpdir(), "localbolo-codes-"));
  try {
    const { client, keys } = provider();
    const output = join(dir, "codes.csv");
    await exportCodes(client, { count: 3, productId: "pdt_localbolo", customerId: "cus_inventory", output, environment: "test_mode", macs });
    const lines = (await readFile(output, "utf8")).trim().split("\n");
    assert.equal(lines.shift(), "code");
    assert.equal(lines.length, 3);
    assert.equal(new Set(lines).size, 3);
    assert.ok(lines.every(key => keys.has(key) && keys.get(key)?.activations_limit === macs));
    assert.equal((await stat(output)).mode & 0o777, 0o600);
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test("a lost response recovers the registered key on resume without creating another", async () => {
  const dir = await mkdtemp(join(tmpdir(), "localbolo-codes-"));
  try {
    const { client, keys } = provider();
    const create = client.licenseKeys.create;
    let loseResponse = true;
    client.licenseKeys.create = async args => {
      const record = await create(args);
      if (loseResponse) {
        loseResponse = false;
        throw Object.assign(new Error("Response lost"), { status: 503 });
      }
      return record;
    };
    const options = { count: 3, productId: "pdt_localbolo", customerId: "cus_inventory", output: join(dir, "codes.csv"), environment: "test_mode" };
    await assert.rejects(exportCodes(client, options), /Response lost/);
    assert.equal(keys.size, 1);
    await exportCodes(client, options);
    assert.equal(keys.size, 3);
    assert.equal((await readFile(options.output, "utf8")).trim().split("\n").length, 4);
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test("a partial failure writes no CSV and resumes the same batch without duplicate licenses", async () => {
  const dir = await mkdtemp(join(tmpdir(), "localbolo-codes-"));
  try {
    const { client, keys, failOn } = provider();
    const options = { count: 3, productId: "pdt_localbolo", customerId: "cus_inventory", output: join(dir, "codes.csv"), environment: "test_mode" };
    failOn(2);
    await assert.rejects(exportCodes(client, options), /Provider unavailable/);
    await assert.rejects(readFile(options.output), { code: "ENOENT" });
    assert.equal(keys.size, 1);
    failOn(0);
    await exportCodes(client, options);
    assert.equal(keys.size, 3);
    assert.equal((await readFile(options.output, "utf8")).trim().split("\n").length, 4);
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test("a key with the wrong activation limit cannot enter the exported CSV", async () => {
  const dir = await mkdtemp(join(tmpdir(), "localbolo-codes-"));
  try {
    const { client } = provider();
    const create = client.licenseKeys.create;
    client.licenseKeys.create = async args => ({ ...await create(args), activations_limit: 2 });
    const output = join(dir, "codes.csv");
    await assert.rejects(exportCodes(client, { count: 1, productId: "pdt_localbolo", customerId: "cus_inventory", output, environment: "test_mode" }), /selected Mac limit/);
    await assert.rejects(readFile(output), { code: "ENOENT" });
  } finally { await rm(dir, { recursive: true, force: true }); }
});

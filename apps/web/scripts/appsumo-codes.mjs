import DodoPayments from 'dodopayments';
import { randomBytes } from 'node:crypto';
import { mkdir, open, readFile, rename, rm, truncate, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { parseArgs } from 'node:util';
import { pathToFileURL } from 'node:url';
import { licensePlans } from '../src/lib/pricing.ts';
import { verifyPlanProduct } from '../src/lib/checkout.ts';

function checkKey(record, macs) {
  if (record.status !== 'active' || record.activations_limit !== macs || record.expires_at != null) {
    throw new Error('Dodo must return an active, non-expiring key with the selected Mac limit');
  }
}

/** Checkpoint every registration. A failed run never produces a partial CSV. */
export async function exportCodes(client, { count, productId, customerId, output, environment, macs = 1 }, progress = () => {}) {
  if (!Number.isInteger(count) || count < 1 || count > 10000) throw new Error('Count must be 1 to 10000');
  if (![1, 2, 5].includes(macs)) throw new Error('Mac limit must be 1, 2, or 5');
  output = resolve(output);
  await mkdir(dirname(output), { recursive: true, mode: 0o700 });
  const lock = await open(output + '.lock', 'wx', 0o600);
  let journal;
  try {
    await lock.writeFile(String(process.pid));
    const identity = { count, productId, customerId, environment, activations: macs };
    try {
      const prior = JSON.parse(await readFile(output + '.batch.json', 'utf8'));
      if (JSON.stringify(prior) !== JSON.stringify(identity)) throw new Error('This output path belongs to a different batch');
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      await writeFile(output + '.batch.json', JSON.stringify(identity), { flag: 'wx', mode: 0o600 });
    }
    try {
      await readFile(output);
      throw new Error('The completed CSV already exists; use a different output path for another batch');
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    const entries = new Map();
    try {
      const text = await readFile(output + '.journal', 'utf8');
      const end = text.lastIndexOf('\n') + 1;
      if (end !== text.length) await truncate(output + '.journal', Buffer.byteLength(text.slice(0, end)));
      for (const line of text.slice(0, end).split('\n').filter(Boolean)) {
        const entry = JSON.parse(line);
        entries.set(entry.index, entry);
      }
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    journal = await open(output + '.journal', 'a', 0o600);
    async function checkpoint(entry) {
      await journal.writeFile(JSON.stringify(entry) + '\n');
      await journal.sync();
      entries.set(entry.index, entry);
    }
    let recovered;
    async function knownKeys() {
      const records = new Map();
      for await (const record of client.licenseKeys.list({ product_id: productId, customer_id: customerId, source: 'import', page_size: 100 })) records.set(record.key, record);
      return records;
    }
    for (let index = 0; index < count; index++) {
      let entry = entries.get(index);
      if (entry?.id) continue;
      if (!entry) {
        entry = { index, key: 'LBAS-' + randomBytes(16).toString('hex').toUpperCase() };
        await checkpoint(entry);
      }
      let record;
      try {
        record = await client.licenseKeys.create({ key: entry.key, product_id: productId, customer_id: customerId, activations_limit: macs, expires_at: null });
      } catch (error) {
        if (error.status !== 409) throw error;
        recovered ??= await knownKeys();
        record = recovered.get(entry.key);
        if (!record) throw new Error('An existing key could not be recovered for this batch');
      }
      checkKey(record, macs);
      if (record.key !== entry.key) throw new Error('Dodo returned a different key');
      await checkpoint({ ...entry, id: record.id });
      progress(index + 1, count);
    }
    const records = await knownKeys();
    const keys = Array.from({ length: count }, (_, index) => entries.get(index)?.key);
    if (new Set(keys).size !== count || keys.some(key => !key || !records.has(key))) throw new Error('The batch is incomplete or has duplicate keys');
    for (const key of keys) checkKey(records.get(key), macs);
    for (const key of new Set([keys[0], keys.at(-1)])) {
      if (!(await client.licenses.validate({ license_key: key })).valid) throw new Error('Public license validation failed');
    }
    await writeFile(output + '.tmp', 'code\n' + keys.join('\n') + '\n', { mode: 0o600 });
    await rename(output + '.tmp', output);
    return { count, output };
  } finally {
    await journal?.close();
    await lock.close();
    await rm(output + '.lock', { force: true });
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const { values } = parseArgs({ options: { execute: { type: 'boolean', default: false }, count: { type: 'string', default: '10000' }, macs: { type: 'string', default: '1' }, 'customer-id': { type: 'string' }, output: { type: 'string', default: join(homedir(), '.config/localbolo/appsumo-232888/codes.csv') } } });
    const count = Number(values.count);
    const macs = Number(values.macs);
    if (!Number.isInteger(count) || count < 1 || count > 10000) throw new Error('Count must be 1 to 10000');
    if (![1, 2, 5].includes(macs)) throw new Error('Mac limit must be 1, 2, or 5');
    if (!values.execute) {
      console.log(`Would register ${count} non-expiring, ${macs}-Mac keys with Dodo, validate them, and export ${values.output}`);
      console.log('No keys or CSV created. Supply a dedicated --customer-id and pass --execute to run.');
    } else {
      const environment = process.env.DODO_PAYMENTS_ENVIRONMENT;
      const plan = licensePlans.find(item => item.macs === macs);
      const productId = process.env[plan.productEnv];
      if (!['live_mode', 'test_mode'].includes(environment) || !process.env.DODO_PAYMENTS_API_KEY || !productId || !values['customer-id']) throw new Error(`Set the Dodo mode, matching API key, ${plan.productEnv}, and --customer-id`);
      const client = new DodoPayments({ bearerToken: process.env.DODO_PAYMENTS_API_KEY, environment, maxRetries: 5 });
      verifyPlanProduct(await client.products.retrieve(productId), plan);
      console.log(`Registering ${count} keys in ${environment}. Keep the CSV and its checkpoint files private.`);
      const result = await exportCodes(client, { count, productId, customerId: values['customer-id'], output: values.output, environment, macs }, (done, total) => { if (done % 100 === 0 || done === total) console.log(`${done}/${total} keys registered`); });
      console.log(`Created ${result.count} verified keys: ${result.output}`);
    }
  } catch (error) {
    console.error(error.status ? `Dodo request failed (HTTP ${error.status}); rerun the same command to resume.` : error.message);
    process.exitCode = 1;
  }
}

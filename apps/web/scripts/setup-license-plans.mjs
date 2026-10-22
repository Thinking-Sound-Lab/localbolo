import DodoPayments from 'dodopayments';
import { writeFile } from 'node:fs/promises';
import { licensePlans } from '../src/lib/pricing.ts';
import { verifyPlanProduct } from '../src/lib/checkout.ts';

const apply = process.argv.includes('--execute');
if (!apply) {
  console.log('Will create/reuse 1-, 2-, and 5-Mac license entitlements and products for 1/$49, 2/$99, and 5/$299.');
  console.log('Pass --execute to configure Dodo. Existing products and licenses are left intact.');
} else {
  try {
    const environment = process.env.DODO_PAYMENTS_ENVIRONMENT;
    if (!['test_mode', 'live_mode'].includes(environment) || !process.env.DODO_PAYMENTS_API_KEY) {
      throw new Error('Set DODO_PAYMENTS_ENVIRONMENT and its matching DODO_PAYMENTS_API_KEY');
    }
    const client = new DodoPayments({ bearerToken: process.env.DODO_PAYMENTS_API_KEY, environment, maxRetries: 3 });
    const catalog = 'localbolo_mac_tiers_v1';
    const entitlements = [];
    for await (const item of client.entitlements.list()) {
      if (item.metadata?.localbolo_catalog === catalog && item.integration_type === 'license_key') entitlements.push(item);
    }
    const products = [];
    for await (const item of client.products.list()) {
      if (item.metadata?.localbolo_catalog === catalog) products.push(item);
    }
    const env = {};
    for (const plan of licensePlans) {
      let entitlement = entitlements.find(item => item.metadata?.localbolo_plan === plan.id);
      entitlement ??= await client.entitlements.create({
        name: `LocalBolo: ${plan.name} per key`, integration_type: 'license_key',
        integration_config: { activations_limit: plan.macs, fulfillment_mode: 'auto', activation_message: `Download LocalBolo at https://localbolo.app/download. Use this key on up to ${plan.name}. Deactivate a Mac in Settings > License before moving an activation.` },
        metadata: { localbolo_catalog: catalog, localbolo_plan: plan.id },
      });
      let product = products.find(item => item.metadata?.localbolo_plan === plan.id);
      product ??= await client.products.create({
        name: `LocalBolo for ${plan.name}`,
        description: `One lifetime license key for ${plan.name}`,
        price: { type: 'one_time_price', currency: 'USD', price: plan.price * 100, purchasing_power_parity: false, pay_what_you_want: false, tax_inclusive: false },
        tax_category: 'digital_products',
        entitlements: [{ entitlement_id: entitlement.id }],
        metadata: { localbolo_catalog: catalog, localbolo_plan: plan.id },
      });
      // A product copied into live mode keeps its price but loses its license
      // key. Attach the plan's key, but never replace a different one.
      const attached = (await client.products.retrieve(product.product_id)).entitlements
        .filter(item => item.integration_type === 'license_key');
      if (attached.length === 0) {
        await client.products.update(product.product_id, { entitlements: [{ entitlement_id: entitlement.id }] });
        console.log(`Attached the ${plan.name} license key to ${product.product_id}.`);
      } else if (attached.length !== 1 || attached[0].id !== entitlement.id) {
        throw new Error(`${product.product_id} already issues a different license key; fix it in the Dodo dashboard`);
      }
      verifyPlanProduct(await client.products.retrieve(product.product_id), plan);
      env[plan.productEnv] = product.product_id;
    }
    console.log(`Configured ${environment}. Set these variables in the matching website environment:`);
    for (const [key, value] of Object.entries(env)) console.log(`${key}=${value}`);
    const output = process.argv[process.argv.indexOf('--output') + 1];
    if (process.argv.includes('--output')) await writeFile(output, JSON.stringify(env, null, 2) + '\n', { mode: 0o600 });
  } catch (error) {
    console.error(error.status ? `Dodo configuration failed (HTTP ${error.status})` : error.message);
    process.exitCode = 1;
  }
}

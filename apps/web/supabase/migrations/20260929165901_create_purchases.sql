-- Everyone who has bought LocalBolo: one row per payment. The Dodo Payments
-- webhook (/api/webhooks/dodo) keeps it up to date, and Dodo stays the source
-- of truth, so any row can be rebuilt from the payment it came from.
create table public.purchases (
  payment_id text primary key,
  customer_id text not null,
  email text not null,
  name text not null,
  -- Two-letter country code from the billing address.
  country text not null,
  -- What the buyer paid, tax included, in the smallest unit of the currency
  -- (cents for USD).
  amount integer not null,
  currency text not null,
  status text not null check (
    status in ('paid', 'partially_refunded', 'refunded', 'disputed', 'charged_back')
  ),
  -- Dodo's ID for the license key (lic_…), never the key itself.
  license_key_id text,
  purchased_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create index purchases_email_idx on public.purchases (lower(email));
create index purchases_customer_id_idx on public.purchases (customer_id);

-- Only the website's server may read or write purchases, with the secret key
-- (the service_role role). The grants are explicit because Supabase no longer
-- grants new tables to every role, and row level security with no policies
-- keeps the publishable key out even if they come back.
alter table public.purchases enable row level security;
revoke all on public.purchases from anon, authenticated, service_role;
grant select, insert, update on public.purchases to service_role;

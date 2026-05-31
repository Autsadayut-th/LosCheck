create table if not exists public.customers (
  id bigint generated always as identity primary key,
  phone text not null,
  name text not null,
  address text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.trip_records (
  id bigint generated always as identity primary key,
  distance_label text not null,
  rate_baht integer not null check (rate_baht > 0),
  rounds integer not null check (rounds > 0),
  created_at timestamptz not null default now()
);

create index if not exists customers_phone_idx on public.customers (phone);
create index if not exists trip_records_created_at_idx on public.trip_records (created_at desc);

alter table public.customers enable row level security;
alter table public.trip_records enable row level security;

create policy "demo can read customers"
on public.customers
for select
to anon
using (true);

create policy "demo can insert customers"
on public.customers
for insert
to anon
with check (true);

create policy "demo can read trip records"
on public.trip_records
for select
to anon
using (true);

create policy "demo can insert trip records"
on public.trip_records
for insert
to anon
with check (true);

create policy "demo can update customers"
on public.customers
for update
to anon
using (true)
with check (true);

create policy "demo can delete customers"
on public.customers
for delete
to anon
using (true);

create policy "demo can update trip records"
on public.trip_records
for update
to anon
using (true)
with check (true);

create policy "demo can delete trip records"
on public.trip_records
for delete
to anon
using (true);

-- UniSwap core marketplace schema.
-- Designed for one college at launch while preserving an institution boundary.

create extension if not exists pgcrypto;
create extension if not exists pg_cron with schema extensions;
create schema if not exists private;

create type public.member_role as enum ('student', 'admin');
create type public.member_status as enum ('active', 'suspended', 'banned');
create type public.listing_format as enum ('fixed_price', 'auction');
create type public.listing_status as enum ('draft', 'published', 'reserved', 'sold', 'expired', 'removed');
create type public.item_condition as enum ('new', 'like_new', 'good', 'fair', 'poor');
create type public.offer_status as enum ('pending', 'countered', 'accepted', 'declined', 'withdrawn', 'expired');
create type public.transaction_source as enum ('fixed_price', 'offer', 'auction', 'buy_now');
create type public.transaction_status as enum ('pending_handoff', 'completed', 'cancelled', 'disputed');

create table public.institutions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  allowed_email_domain text not null unique check (allowed_email_domain = lower(allowed_email_domain)),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  institution_id uuid not null references public.institutions(id),
  display_name text not null check (char_length(display_name) between 2 and 60),
  avatar_url text,
  bio text check (char_length(bio) <= 280),
  role public.member_role not null default 'student',
  status public.member_status not null default 'active',
  completed_sales integer not null default 0 check (completed_sales >= 0),
  average_rating numeric(3, 2) check (average_rating between 1 and 5),
  rating_count integer not null default 0 check (rating_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_institution_id_idx on public.profiles(institution_id);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid references public.institutions(id) on delete cascade,
  name text not null,
  slug text not null,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  unique nulls not distinct (institution_id, slug)
);

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id),
  seller_id uuid not null references public.profiles(user_id),
  category_id uuid references public.categories(id),
  format public.listing_format not null,
  status public.listing_status not null default 'draft',
  title text not null check (char_length(title) between 3 and 100),
  description text not null check (char_length(description) between 10 and 3000),
  condition public.item_condition not null,
  price numeric(12, 2) check (price is null or price > 0),
  accepts_offers boolean not null default false,
  handoff_location text check (char_length(handoff_location) <= 120),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint listing_price_matches_format check (
    (format = 'fixed_price' and price is not null) or
    (format = 'auction' and price is null)
  )
);

create index listings_institution_status_idx on public.listings(institution_id, status, created_at desc);
create index listings_seller_id_idx on public.listings(seller_id);
create index listings_category_id_idx on public.listings(category_id);

create table public.listing_images (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  storage_path text not null unique,
  alt_text text not null check (char_length(alt_text) between 3 and 180),
  sort_order smallint not null check (sort_order between 0 and 4),
  width integer not null check (width > 0),
  height integer not null check (height > 0),
  created_at timestamptz not null default now(),
  unique (listing_id, sort_order)
);

create index listing_images_listing_id_idx on public.listing_images(listing_id);

create table public.auctions (
  listing_id uuid primary key references public.listings(id) on delete cascade,
  start_price numeric(12, 2) not null check (start_price > 0),
  bid_increment numeric(12, 2) not null check (bid_increment > 0),
  reserve_price numeric(12, 2) check (reserve_price is null or reserve_price >= start_price),
  buy_now_price numeric(12, 2) check (buy_now_price is null or buy_now_price > start_price),
  current_price numeric(12, 2) not null check (current_price > 0),
  highest_bidder_id uuid references public.profiles(user_id),
  highest_max_bid numeric(12, 2),
  reserve_met boolean not null default false,
  bid_count integer not null default 0 check (bid_count >= 0),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  original_ends_at timestamptz not null,
  finalized_at timestamptz,
  check (ends_at > starts_at),
  check (highest_max_bid is null or highest_max_bid >= current_price)
);

create index auctions_ends_at_idx on public.auctions(ends_at) where finalized_at is null;
create index auctions_highest_bidder_id_idx on public.auctions(highest_bidder_id);

create table public.bids (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.auctions(listing_id) on delete cascade,
  bidder_id uuid not null references public.profiles(user_id),
  maximum_amount numeric(12, 2) not null check (maximum_amount > 0),
  displayed_amount numeric(12, 2) not null check (displayed_amount > 0),
  was_leading boolean not null,
  created_at timestamptz not null default now()
);

create index bids_listing_created_idx on public.bids(listing_id, created_at desc);
create index bids_bidder_id_idx on public.bids(bidder_id);

create table public.offers (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  buyer_id uuid not null references public.profiles(user_id),
  amount numeric(12, 2) not null check (amount > 0),
  status public.offer_status not null default 'pending',
  parent_offer_id uuid references public.offers(id),
  expires_at timestamptz not null default (now() + interval '48 hours'),
  created_at timestamptz not null default now(),
  responded_at timestamptz
);

create index offers_listing_id_idx on public.offers(listing_id, created_at desc);
create index offers_buyer_id_idx on public.offers(buyer_id);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id),
  listing_id uuid not null unique references public.listings(id),
  seller_id uuid not null references public.profiles(user_id),
  buyer_id uuid not null references public.profiles(user_id),
  source public.transaction_source not null,
  agreed_price numeric(12, 2) not null check (agreed_price > 0),
  status public.transaction_status not null default 'pending_handoff',
  handoff_due_at timestamptz not null default (now() + interval '72 hours'),
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text check (char_length(cancellation_reason) <= 500),
  created_at timestamptz not null default now(),
  check (seller_id <> buyer_id)
);

create index transactions_seller_id_idx on public.transactions(seller_id, created_at desc);
create index transactions_buyer_id_idx on public.transactions(buyer_id, created_at desc);

create table public.handoff_confirmations (
  transaction_id uuid not null references public.transactions(id) on delete cascade,
  user_id uuid not null references public.profiles(user_id),
  confirmed_at timestamptz not null default now(),
  primary key (transaction_id, user_id)
);

create table public.favorites (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

create index favorites_listing_id_idx on public.favorites(listing_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

create trigger listings_set_updated_at before update on public.listings
for each row execute function public.set_updated_at();

create or replace function private.current_institution_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select institution_id from public.profiles
  where user_id = (select auth.uid()) and status = 'active'
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where user_id = (select auth.uid()) and role = 'admin' and status = 'active'
  )
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  matched_institution uuid;
  proposed_name text;
begin
  select id into matched_institution
  from public.institutions
  where is_active = true
    and allowed_email_domain = lower(split_part(new.email, '@', 2));

  if matched_institution is null then
    raise exception 'Email domain is not approved for this marketplace';
  end if;

  proposed_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    split_part(new.email, '@', 1)
  );

  insert into public.profiles (user_id, institution_id, display_name)
  values (new.id, matched_institution, left(proposed_name, 60));
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.institutions enable row level security;
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.listings enable row level security;
alter table public.listing_images enable row level security;
alter table public.auctions enable row level security;
alter table public.bids enable row level security;
alter table public.offers enable row level security;
alter table public.transactions enable row level security;
alter table public.handoff_confirmations enable row level security;
alter table public.favorites enable row level security;

revoke all on all tables in schema public from anon, authenticated;
grant usage on schema public, private to authenticated;
grant select on public.institutions, public.profiles, public.categories, public.listings,
  public.listing_images, public.auctions, public.transactions to authenticated;
grant insert, update, delete on public.listings, public.listing_images to authenticated;
grant insert on public.offers, public.handoff_confirmations, public.favorites to authenticated;
grant delete on public.favorites to authenticated;
grant select on public.offers, public.handoff_confirmations, public.favorites to authenticated;
grant update (display_name, avatar_url, bio) on public.profiles to authenticated;

create policy "members read their institution"
on public.institutions for select to authenticated
using (id = (select private.current_institution_id()));

create policy "members read campus profiles"
on public.profiles for select to authenticated
using (institution_id = (select private.current_institution_id()));

create policy "members update their profile"
on public.profiles for update to authenticated
using (user_id = (select auth.uid()) and status = 'active')
with check (user_id = (select auth.uid()) and institution_id = (select private.current_institution_id()));

create policy "members read campus categories"
on public.categories for select to authenticated
using (institution_id is null or institution_id = (select private.current_institution_id()));

create policy "members read campus listings"
on public.listings for select to authenticated
using (
  institution_id = (select private.current_institution_id())
  and (status in ('published', 'reserved', 'sold', 'expired') or seller_id = (select auth.uid()) or (select private.is_admin()))
);

create policy "members create their listings"
on public.listings for insert to authenticated
with check (
  seller_id = (select auth.uid())
  and institution_id = (select private.current_institution_id())
  and status in ('draft', 'published')
);

create policy "sellers and admins update listings"
on public.listings for update to authenticated
using (seller_id = (select auth.uid()) or (select private.is_admin()))
with check (
  institution_id = (select private.current_institution_id())
  and (seller_id = (select auth.uid()) or (select private.is_admin()))
);

create policy "sellers delete draft listings"
on public.listings for delete to authenticated
using (seller_id = (select auth.uid()) and status = 'draft');

create policy "members read campus listing images"
on public.listing_images for select to authenticated
using (exists (
  select 1 from public.listings l
  where l.id = listing_id and l.institution_id = (select private.current_institution_id())
));

create policy "sellers manage listing images"
on public.listing_images for all to authenticated
using (exists (select 1 from public.listings l where l.id = listing_id and l.seller_id = (select auth.uid())))
with check (exists (select 1 from public.listings l where l.id = listing_id and l.seller_id = (select auth.uid())));

create policy "members read campus auctions"
on public.auctions for select to authenticated
using (exists (
  select 1 from public.listings l
  where l.id = listing_id and l.institution_id = (select private.current_institution_id())
));

create policy "participants read offers"
on public.offers for select to authenticated
using (
  buyer_id = (select auth.uid()) or exists (
    select 1 from public.listings l where l.id = listing_id and l.seller_id = (select auth.uid())
  ) or (select private.is_admin())
);

create policy "buyers create offers"
on public.offers for insert to authenticated
with check (
  buyer_id = (select auth.uid()) and exists (
    select 1 from public.listings l
    where l.id = listing_id
      and l.institution_id = (select private.current_institution_id())
      and l.seller_id <> (select auth.uid())
      and l.format = 'fixed_price'
      and l.status = 'published'
      and l.accepts_offers = true
  )
);

create policy "participants read transactions"
on public.transactions for select to authenticated
using (seller_id = (select auth.uid()) or buyer_id = (select auth.uid()) or (select private.is_admin()));

create policy "participants read handoff confirmations"
on public.handoff_confirmations for select to authenticated
using (exists (
  select 1 from public.transactions t
  where t.id = transaction_id and ((select auth.uid()) in (t.seller_id, t.buyer_id) or (select private.is_admin()))
));

create policy "participants confirm handoff"
on public.handoff_confirmations for insert to authenticated
with check (
  user_id = (select auth.uid()) and exists (
    select 1 from public.transactions t
    where t.id = transaction_id and (select auth.uid()) in (t.seller_id, t.buyer_id)
      and t.status = 'pending_handoff'
  )
);

create policy "users read favorites"
on public.favorites for select to authenticated
using (user_id = (select auth.uid()));

create policy "users add favorites"
on public.favorites for insert to authenticated
with check (user_id = (select auth.uid()) and exists (
  select 1 from public.listings l
  where l.id = listing_id and l.institution_id = (select private.current_institution_id())
));

create policy "users remove favorites"
on public.favorites for delete to authenticated
using (user_id = (select auth.uid()));

create or replace function public.configure_auction(
  p_listing_id uuid,
  p_start_price numeric,
  p_bid_increment numeric,
  p_reserve_price numeric,
  p_buy_now_price numeric,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns public.auctions
language plpgsql
security definer
set search_path = ''
as $$
declare
  listing public.listings%rowtype;
  created_auction public.auctions%rowtype;
begin
  select * into listing from public.listings where id = p_listing_id for update;

  if listing.id is null then raise exception 'Listing not found'; end if;
  if listing.seller_id <> (select auth.uid()) then raise exception 'Only the seller can configure an auction'; end if;
  if listing.institution_id <> (select private.current_institution_id()) then raise exception 'Listing is outside your institution'; end if;
  if listing.format <> 'auction' or listing.status not in ('draft', 'published') then raise exception 'Listing cannot be configured as an auction'; end if;
  if p_start_price <= 0 or p_bid_increment <= 0 then raise exception 'Auction amounts must be positive'; end if;
  if p_reserve_price is not null and p_reserve_price < p_start_price then raise exception 'Reserve must be at least the start price'; end if;
  if p_buy_now_price is not null and p_buy_now_price <= p_start_price then raise exception 'Buy Now must exceed the start price'; end if;
  if p_starts_at < now() - interval '1 minute' or p_ends_at <= p_starts_at then raise exception 'Auction timing is invalid'; end if;

  insert into public.auctions (
    listing_id, start_price, bid_increment, reserve_price, buy_now_price,
    current_price, starts_at, ends_at, original_ends_at
  ) values (
    p_listing_id, p_start_price, p_bid_increment, p_reserve_price, p_buy_now_price,
    p_start_price, p_starts_at, p_ends_at, p_ends_at
  )
  returning * into created_auction;

  return created_auction;
end;
$$;

revoke all on function public.configure_auction(uuid, numeric, numeric, numeric, numeric, timestamptz, timestamptz) from public, anon;
grant execute on function public.configure_auction(uuid, numeric, numeric, numeric, numeric, timestamptz, timestamptz) to authenticated;

create or replace function public.place_bid(p_listing_id uuid, p_maximum_amount numeric)
returns table (
  current_price numeric,
  highest_bidder_id uuid,
  bid_count integer,
  reserve_met boolean,
  ends_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  bidder uuid := (select auth.uid());
  auction public.auctions%rowtype;
  listing public.listings%rowtype;
  next_price numeric(12, 2);
  next_leader uuid;
  next_max numeric(12, 2);
  next_reserve_met boolean;
  next_end timestamptz;
begin
  if bidder is null then raise exception 'Authentication required'; end if;
  if p_maximum_amount is null or p_maximum_amount <= 0 then raise exception 'Bid must be positive'; end if;

  select * into auction from public.auctions where listing_id = p_listing_id for update;
  select * into listing from public.listings where id = p_listing_id;

  if auction.listing_id is null or listing.id is null then raise exception 'Auction not found'; end if;
  if listing.institution_id <> (select private.current_institution_id()) then raise exception 'Auction is outside your institution'; end if;
  if listing.seller_id = bidder then raise exception 'Sellers cannot bid on their own listing'; end if;
  if listing.status <> 'published' or now() < auction.starts_at or now() >= auction.ends_at or auction.finalized_at is not null then
    raise exception 'Auction is not accepting bids';
  end if;
  if p_maximum_amount < auction.start_price
    or (auction.highest_bidder_id is not null and p_maximum_amount <= auction.current_price) then
    raise exception 'Bid is below the minimum required amount';
  end if;

  next_price := auction.current_price;
  next_leader := auction.highest_bidder_id;
  next_max := auction.highest_max_bid;

  if auction.highest_bidder_id is null then
    next_leader := bidder;
    next_max := p_maximum_amount;
    next_price := auction.start_price;
  elsif auction.highest_bidder_id = bidder then
    if p_maximum_amount <= auction.highest_max_bid then raise exception 'New maximum must exceed your previous maximum'; end if;
    next_max := p_maximum_amount;
  elsif p_maximum_amount > auction.highest_max_bid then
    next_leader := bidder;
    next_max := p_maximum_amount;
    next_price := least(p_maximum_amount, greatest(auction.current_price + auction.bid_increment, auction.highest_max_bid + auction.bid_increment));
  else
    next_price := least(auction.highest_max_bid, p_maximum_amount + auction.bid_increment);
  end if;

  if auction.reserve_price is not null and next_max >= auction.reserve_price and next_price < auction.reserve_price then
    next_price := auction.reserve_price;
  end if;

  next_reserve_met := auction.reserve_price is null or next_max >= auction.reserve_price;
  next_end := case when auction.ends_at - now() <= interval '2 minutes'
    then auction.ends_at + interval '2 minutes' else auction.ends_at end;

  update public.auctions set
    current_price = next_price,
    highest_bidder_id = next_leader,
    highest_max_bid = next_max,
    reserve_met = next_reserve_met,
    bid_count = auctions.bid_count + 1,
    ends_at = next_end
  where listing_id = p_listing_id;

  insert into public.bids (listing_id, bidder_id, maximum_amount, displayed_amount, was_leading)
  values (p_listing_id, bidder, p_maximum_amount, next_price, next_leader = bidder);

  return query select next_price, next_leader, auction.bid_count + 1, next_reserve_met, next_end;
end;
$$;

revoke all on function public.place_bid(uuid, numeric) from public, anon;
grant execute on function public.place_bid(uuid, numeric) to authenticated;

create or replace function public.my_bids(p_listing_id uuid)
returns table (id uuid, maximum_amount numeric, displayed_amount numeric, was_leading boolean, created_at timestamptz)
language sql
security definer
set search_path = ''
as $$
  select b.id, b.maximum_amount, b.displayed_amount, b.was_leading, b.created_at
  from public.bids b
  join public.listings l on l.id = b.listing_id
  where b.listing_id = p_listing_id
    and b.bidder_id = (select auth.uid())
    and l.institution_id = (select private.current_institution_id())
  order by b.created_at desc
$$;

revoke all on function public.my_bids(uuid) from public, anon;
grant execute on function public.my_bids(uuid) to authenticated;

create or replace function private.finalize_expired_auctions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  auction_record record;
  finalized_count integer := 0;
begin
  for auction_record in
    select a.*, l.seller_id, l.institution_id
    from public.auctions a
    join public.listings l on l.id = a.listing_id
    where a.finalized_at is null and a.ends_at <= now() and l.status = 'published'
    for update of a, l skip locked
  loop
    if auction_record.highest_bidder_id is not null and auction_record.reserve_met then
      insert into public.transactions (institution_id, listing_id, seller_id, buyer_id, source, agreed_price)
      values (auction_record.institution_id, auction_record.listing_id, auction_record.seller_id,
        auction_record.highest_bidder_id, 'auction', auction_record.current_price)
      on conflict (listing_id) do nothing;
      update public.listings set status = 'reserved' where id = auction_record.listing_id;
    else
      update public.listings set status = 'expired' where id = auction_record.listing_id;
    end if;

    update public.auctions set finalized_at = now() where listing_id = auction_record.listing_id;
    finalized_count := finalized_count + 1;
  end loop;
  return finalized_count;
end;
$$;

revoke all on function private.finalize_expired_auctions() from public, anon, authenticated;

-- Run auction finalization every minute through Supabase Cron.
select cron.schedule(
  'finalize-expired-auctions',
  '* * * * *',
  'select private.finalize_expired_auctions()'
);

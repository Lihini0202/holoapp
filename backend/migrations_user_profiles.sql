-- ============================================================================
-- Separate app-user profiles from the ghosted-partner ledger.
--
-- The `profiles` table is written by two unrelated code paths:
--   * tasks.py update_ledger  -> user_hash = sha256(name|age|location)  (a partner)
--   * edit_profile_screen     -> user_hash = the auth UUID              (an app user)
--
-- Because Ghost Search reads `profiles`, saving your own profile would have made
-- you searchable as a ghosted partner. This table keeps the two apart.
-- ============================================================================

create table if not exists user_profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  first_name  text,
  last_name   text,
  country     text,
  birthdate   date,
  updated_at  timestamptz not null default now()
);

alter table user_profiles enable row level security;

-- A user may read and write only their own row.
drop policy if exists "own profile select" on user_profiles;
create policy "own profile select" on user_profiles
  for select using (auth.uid() = id);

drop policy if exists "own profile upsert" on user_profiles;
create policy "own profile upsert" on user_profiles
  for insert with check (auth.uid() = id);

drop policy if exists "own profile update" on user_profiles;
create policy "own profile update" on user_profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- Safety net: remove any app-user rows that were already written into the
-- partner ledger. A partner hash is 64 hex characters; an auth UUID is 36 with
-- dashes, so the two are easy to tell apart.
delete from profiles
where length(user_hash) = 36 and user_hash like '%-%-%-%-%';

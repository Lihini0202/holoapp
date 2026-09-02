-- ============================================================================
-- Profile photos.
--
-- The `avatars` bucket has already been created (public, 2 MB, images only).
-- This adds the column that stores the resulting URL and the policies that let a
-- user manage only their own file.
-- ============================================================================

alter table user_profiles
  add column if not exists avatar_url text;

-- Files are stored as "<auth-uid>/avatar.<ext>", so the first path segment is the
-- owner. Each policy checks that segment against auth.uid().

drop policy if exists "avatar upload own" on storage.objects;
create policy "avatar upload own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatar update own" on storage.objects;
create policy "avatar update own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatar delete own" on storage.objects;
create policy "avatar delete own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- The bucket is public so avatars render without signed URLs.
drop policy if exists "avatar read all" on storage.objects;
create policy "avatar read all" on storage.objects
  for select using (bucket_id = 'avatars');

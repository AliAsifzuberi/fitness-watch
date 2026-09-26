-- Run this in the Supabase SQL editor (Dashboard → SQL).

-- 1) Metadata table
create table if not exists public.recordings (
  id bigint generated always as identity primary key,
  session_id text not null,
  label text not null,
  true_reps integer not null default 0,
  weight_kg double precision,
  subject_id text not null,
  wrist text not null default 'left',
  file_name text not null,
  storage_path text not null,
  created_at timestamptz not null default now()
);

-- 2) Storage bucket (also creatable in Dashboard → Storage)
insert into storage.buckets (id, name, public)
values ('motion-recordings', 'motion-recordings', false)
on conflict (id) do nothing;

-- 3) PERSONAL PROJECT POLICIES
-- For solo/dev use with the anon key, allow insert/select on this bucket + table.
-- Tighten these before any real multi-user release.

alter table public.recordings enable row level security;

create policy "allow_anon_insert_recordings"
  on public.recordings for insert
  to anon
  with check (true);

create policy "allow_anon_select_recordings"
  on public.recordings for select
  to anon
  using (true);

create policy "allow_anon_storage_insert"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'motion-recordings');

create policy "allow_anon_storage_select"
  on storage.objects for select
  to anon
  using (bucket_id = 'motion-recordings');

create policy "allow_anon_storage_update"
  on storage.objects for update
  to anon
  using (bucket_id = 'motion-recordings');

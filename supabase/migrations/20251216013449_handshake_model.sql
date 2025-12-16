-- Fermentors ↔ Canvas handshake model
-- Goal:
--  - Fermentors stores real user identity (Supabase auth + profile)
--  - Canvas never receives real identity; only an alias code/binding
--  - Binding is created when student submits alias_code in a Canvas verification assignment
--  - Fermentors server (service role) matches Canvas submissions → alias_code → Fermentors user

begin;

-- Extensions
create extension if not exists pgcrypto;

-- 1) Profile table (optional; keep PII minimal here; auth.users stores email)
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- auto-updated timestamp
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end; $$;

drop trigger if exists trg_profiles_touch on public.profiles;
create trigger trg_profiles_touch
before update on public.profiles
for each row execute function public.touch_updated_at();

-- 2) Handshake intent: Fermentors generates alias_code per (user, course_slug)
--    Student pastes alias_code into Canvas verification assignment (text submission).
create table if not exists public.course_handshakes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  course_slug text not null,
  alias_code text not null,  -- what the student pastes into Canvas
  created_at timestamptz not null default now(),
  bound_at timestamptz,
  unique (course_slug, alias_code),
  unique (user_id, course_slug)
);

-- 3) Canvas binding result: once Fermentors server finds a matching submission
--    it stores the Canvas user_id (pseudonymous) + submission metadata.
create table if not exists public.canvas_bindings (
  id uuid primary key default gen_random_uuid(),
  handshake_id uuid not null references public.course_handshakes(id) on delete cascade,
  course_slug text not null,
  canvas_course_id bigint not null,
  canvas_user_id bigint not null,
  canvas_submission_id bigint,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (course_slug, canvas_course_id, canvas_user_id),
  unique (handshake_id)
);

-- 4) Progress events (minimal, append-only)
--    You can later add rollups/materialized views.
create table if not exists public.progress_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  course_slug text not null,
  event_type text not null,              -- e.g., "quiz_completed", "module_completed"
  event_payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists idx_progress_events_user_course_time
  on public.progress_events (user_id, course_slug, occurred_at desc);

-- -------------------
-- RLS (Row Level Security)
-- -------------------
alter table public.profiles enable row level security;
alter table public.course_handshakes enable row level security;
alter table public.canvas_bindings enable row level security;
alter table public.progress_events enable row level security;

-- profiles: user can read/write only their own row
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles for select
using (auth.uid() = user_id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles for insert
with check (auth.uid() = user_id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- course_handshakes: user can manage only their own handshake
drop policy if exists "handshakes_select_own" on public.course_handshakes;
create policy "handshakes_select_own"
on public.course_handshakes for select
using (auth.uid() = user_id);

drop policy if exists "handshakes_insert_own" on public.course_handshakes;
create policy "handshakes_insert_own"
on public.course_handshakes for insert
with check (auth.uid() = user_id);

drop policy if exists "handshakes_update_own" on public.course_handshakes;
create policy "handshakes_update_own"
on public.course_handshakes for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- canvas_bindings:
-- users can read only the binding that belongs to their handshake.
-- writes should be done by the server using service role (bypasses RLS).
drop policy if exists "bindings_select_own" on public.canvas_bindings;
create policy "bindings_select_own"
on public.canvas_bindings for select
using (
  exists (
    select 1
    from public.course_handshakes h
    where h.id = canvas_bindings.handshake_id
      and h.user_id = auth.uid()
  )
);

-- progress_events: user can read/write only their own events (server can write too)
drop policy if exists "progress_select_own" on public.progress_events;
create policy "progress_select_own"
on public.progress_events for select
using (auth.uid() = user_id);

drop policy if exists "progress_insert_own" on public.progress_events;
create policy "progress_insert_own"
on public.progress_events for insert
with check (auth.uid() = user_id);

commit;

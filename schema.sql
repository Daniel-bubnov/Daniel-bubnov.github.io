-- =====================================================================
-- Схема для приложения тренировок. Выполнить целиком в Supabase:
-- Dashboard → SQL Editor → New query → вставить → Run
-- =====================================================================

-- ---------- Упражнения (личная библиотека) ----------
create table if not exists public.exercises (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name         text not null,
  muscle_group text,
  equipment    text,          -- тренажёр / инвентарь, где стоит в зале
  notes        text,          -- заметки по технике
  photo_path   text,          -- путь к фото в Storage
  video_path   text,          -- путь к загруженному видео в Storage
  video_url    text,          -- или ссылка на видео (YouTube и т.п.)
  rest_seconds int,           -- своё время отдыха, сек
  archived     boolean not null default false,  -- скрыто из библиотеки, история сохраняется
  created_at   timestamptz not null default now()
);

-- ---------- Тренировки (по датам) ----------
create table if not exists public.workouts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date       date not null,
  title      text,
  notes      text,
  completed  boolean not null default false,
  started_at  timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists workouts_user_date_idx on public.workouts (user_id, date);

-- ---------- Упражнения внутри тренировки ----------
create table if not exists public.workout_exercises (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  workout_id  uuid not null references public.workouts(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id) on delete restrict,
  position    int  not null default 0,
  notes       text,
  created_at  timestamptz not null default now()
);
create index if not exists we_workout_idx  on public.workout_exercises (workout_id);
create index if not exists we_exercise_idx on public.workout_exercises (exercise_id);

-- ---------- Подходы: план и факт ----------
create table if not exists public.sets (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null default auth.uid() references auth.users(id) on delete cascade,
  workout_exercise_id uuid not null references public.workout_exercises(id) on delete cascade,
  set_number          int  not null,
  planned_reps        int,
  planned_weight      numeric(6,2),
  actual_reps         int,
  actual_weight       numeric(6,2),
  done                boolean not null default false
);
create index if not exists sets_we_idx on public.sets (workout_exercise_id);

-- ---------- Row Level Security: каждый видит только свои строки ----------
alter table public.exercises         enable row level security;
alter table public.workouts          enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.sets              enable row level security;

drop policy if exists "own exercises" on public.exercises;
create policy "own exercises" on public.exercises for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists "own workouts" on public.workouts;
create policy "own workouts" on public.workouts for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists "own workout_exercises" on public.workout_exercises;
create policy "own workout_exercises" on public.workout_exercises for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists "own sets" on public.sets;
create policy "own sets" on public.sets for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ---------- Storage: фото и видео ----------
-- Публичный бакет: файлы открываются по прямой (случайной) ссылке,
-- а загружать и удалять может только владелец — в свою папку <user_id>/...
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 52428800, array['image/*', 'video/*'])
on conflict (id) do nothing;

drop policy if exists "media select own" on storage.objects;
create policy "media select own" on storage.objects for select to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "media insert own" on storage.objects;
create policy "media insert own" on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "media update own" on storage.objects;
create policy "media update own" on storage.objects for update to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "media delete own" on storage.objects;
create policy "media delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);

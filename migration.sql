-- Обновление базы для версии 2.0 («Подход»).
-- Выполнить один раз в Supabase: SQL Editor → New query → вставить → Run.
-- Данные не удаляются, добавляются только новые колонки.

-- Своё время отдыха для упражнения (в секундах)
alter table public.exercises add column if not exists rest_seconds int;

-- Время начала и окончания тренировки — для подсчёта длительности
alter table public.workouts add column if not exists started_at  timestamptz;
alter table public.workouts add column if not exists finished_at timestamptz;

-- Попросить API сразу увидеть новые колонки
notify pgrst, 'reload schema';

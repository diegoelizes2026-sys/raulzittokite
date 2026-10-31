-- Execute no SQL Editor do projeto Supabase Meniuza.
-- Cria uma tabela independente para as aulas Raul Zito Kite.
create table if not exists public.raul_kite_lessons (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  student_name text not null,
  student_phone text,
  lesson_type text not null default 'Aula para iniciantes',
  lesson_date date not null,
  lesson_time time not null,
  status text not null default 'agendada'
    check (status in ('agendada','confirmada','concluida','cancelada')),
  amount numeric(10,2) check (amount is null or amount >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists raul_kite_lessons_owner_date_idx
  on public.raul_kite_lessons(owner_id, lesson_date, lesson_time);
alter table public.raul_kite_lessons enable row level security;
drop policy if exists "Raul gerencia somente suas aulas" on public.raul_kite_lessons;
create policy "Raul gerencia somente suas aulas"
on public.raul_kite_lessons for all
to authenticated
using (auth.uid() = owner_id)
with check (auth.uid() = owner_id);

-- Campos extras para cadastro de alunos e duração das aulas.
alter table public.raul_kite_lessons
 add column if not exists student_locality text,
 add column if not exists student_level text not null default 'iniciante'
   check (student_level in ('iniciante','intermediario')),
 add column if not exists duration_minutes integer not null default 60
   check (duration_minutes in (60,90,120));
create unique index if not exists raul_kite_lessons_owner_slot_unique
 on public.raul_kite_lessons(owner_id, lesson_date, lesson_time)
 where status <> 'cancelada';


-- Cadastro independente de alunos. Migração incremental; preserva aulas existentes.
create table if not exists public.raul_kite_students (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  full_name text not null check (length(trim(full_name)) > 0),
  phone text,
  email text,
  experience_level text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.raul_kite_students enable row level security;
drop policy if exists "Raul gerencia somente seus alunos" on public.raul_kite_students;
create policy "Raul gerencia somente seus alunos" on public.raul_kite_students
for all to authenticated using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);
grant select, insert, update, delete on public.raul_kite_students to authenticated;
create unique index if not exists raul_kite_students_owner_phone_unique
on public.raul_kite_students(owner_id, regexp_replace(coalesce(phone,''), '\\D', '', 'g'))
where nullif(regexp_replace(coalesce(phone,''), '\\D', '', 'g'),'') is not null;
alter table public.raul_kite_lessons add column if not exists student_id uuid
references public.raul_kite_students(id) on delete set null;
grant select, insert, update, delete on public.raul_kite_lessons to authenticated;

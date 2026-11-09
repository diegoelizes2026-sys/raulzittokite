-- Raulzito Kite: multi-instructor roles and row-level isolation.
-- Administrator: Raul's existing Auth user. Execute once in the Supabase SQL Editor.
create table if not exists public.raul_kite_instructors (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  full_name text not null,
  phone text not null,
  email text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint raul_kite_instructors_email_format check (position('@' in email) > 1)
);
create unique index if not exists raul_kite_instructors_email_lower_uidx on public.raul_kite_instructors(lower(email));
create index if not exists raul_kite_instructors_owner_idx on public.raul_kite_instructors(owner_id);
alter table public.raul_kite_instructors enable row level security;
grant select,insert,update,delete on public.raul_kite_instructors to authenticated;

-- Mark the existing Raul account as the only administrator.
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data,'{}'::jsonb) ||
  jsonb_build_object('role','admin','owner_id','0c997ebb-4ac2-4879-9b70-ae410581dea8')
where id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid;

-- Drop the old single-owner policies before installing role-based policies.
do $$
declare t text; p record;
begin
  foreach t in array array[
    'raul_kite_instructors','raul_kite_booking_settings','raul_kite_lesson_packages',
    'raul_kite_lesson_types','raul_kite_lessons','raul_kite_student_credits',
    'raul_kite_student_progress','raul_kite_student_purchases','raul_kite_student_tips',
    'raul_kite_students'
  ] loop
    for p in select policyname from pg_policies where schemaname='public' and tablename=t loop
      execute format('drop policy if exists %I on public.%I',p.policyname,t);
    end loop;
  end loop;
end $$;

create policy "admin manages instructors" on public.raul_kite_instructors
for all to authenticated
using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
create policy "instructor reads own profile" on public.raul_kite_instructors
for select to authenticated using (auth_user_id=(select auth.uid()));

-- The admin can manage all rows; an active instructor can manage rows with owner_id = auth.uid().
create policy "admin manages kite students" on public.raul_kite_students
for all to authenticated
using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
create policy "instructors manage own kite students" on public.raul_kite_students
for all to authenticated
using (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active))
with check (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active));
create policy "students read own kite profile" on public.raul_kite_students
for select to authenticated using (auth_user_id=(select auth.uid()));

create policy "admin manages kite lessons" on public.raul_kite_lessons
for all to authenticated using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
create policy "instructors manage own kite lessons" on public.raul_kite_lessons
for all to authenticated
using (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active))
with check (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active));
create policy "students create own kite bookings" on public.raul_kite_lessons
for insert to authenticated with check (status='agendada' and student_booking=true
  and exists(select 1 from public.raul_kite_students s where s.id=student_id
    and s.auth_user_id=(select auth.uid()) and s.owner_id=owner_id));
create policy "students read own kite lessons" on public.raul_kite_lessons
for select to authenticated using (exists(select 1 from public.raul_kite_students s
  where s.id=student_id and s.auth_user_id=(select auth.uid())));

create policy "admin manages kite booking settings" on public.raul_kite_booking_settings
for all to authenticated using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
create policy "instructors manage own kite booking settings" on public.raul_kite_booking_settings
for all to authenticated using (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active))
with check (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active));
create policy "students read own instructor booking settings" on public.raul_kite_booking_settings
for select to authenticated using (exists(select 1 from public.raul_kite_students s
  where s.auth_user_id=(select auth.uid()) and s.owner_id=raul_kite_booking_settings.owner_id));

create policy "admin manages kite packages" on public.raul_kite_lesson_packages
for all to authenticated using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
create policy "instructors manage own kite packages" on public.raul_kite_lesson_packages
for all to authenticated using (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active))
with check (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active));
create policy "students read active packages of own instructor" on public.raul_kite_lesson_packages
for select to authenticated using (is_active and exists(select 1 from public.raul_kite_students s
  where s.auth_user_id=(select auth.uid()) and s.owner_id=raul_kite_lesson_packages.owner_id));

create policy "admin manages kite lesson types" on public.raul_kite_lesson_types
for all to authenticated using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
create policy "instructors manage own kite lesson types" on public.raul_kite_lesson_types
for all to authenticated using (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active))
with check (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active));
create policy "students read active lesson types of own instructor" on public.raul_kite_lesson_types
for select to authenticated using (is_active and exists(select 1 from public.raul_kite_students s
  where s.auth_user_id=(select auth.uid()) and s.owner_id=raul_kite_lesson_types.owner_id));

create policy "admin manages kite credits" on public.raul_kite_student_credits
for all to authenticated using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
create policy "instructors manage own kite credits" on public.raul_kite_student_credits
for all to authenticated using (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active))
with check (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active));
create policy "students view own kite credits" on public.raul_kite_student_credits
for select to authenticated using (exists(select 1 from public.raul_kite_students s
  where s.id=student_id and s.auth_user_id=(select auth.uid())));

create policy "admin manages kite progress" on public.raul_kite_student_progress
for all to authenticated using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
create policy "instructors manage own kite progress" on public.raul_kite_student_progress
for all to authenticated using (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active))
with check (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active));
create policy "students view published kite progress" on public.raul_kite_student_progress
for select to authenticated using (is_visible and exists(select 1 from public.raul_kite_students s
  where s.id=student_id and s.auth_user_id=(select auth.uid())));

create policy "admin manages kite purchases" on public.raul_kite_student_purchases
for all to authenticated using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
create policy "instructors manage own kite purchases" on public.raul_kite_student_purchases
for all to authenticated using (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active))
with check (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active));
create policy "students request own kite purchases" on public.raul_kite_student_purchases
for insert to authenticated with check (status='pending' and payment_status='pending'
  and exists(select 1 from public.raul_kite_students s where s.id=student_id
    and s.auth_user_id=(select auth.uid()) and s.owner_id=owner_id)
  and exists(select 1 from public.raul_kite_lesson_packages p where p.id=package_id
    and p.owner_id=owner_id and p.is_active and p.lesson_count=lessons_quantity
    and p.price=amount and p.name=package_name));
create policy "students view own kite purchases" on public.raul_kite_student_purchases
for select to authenticated using (exists(select 1 from public.raul_kite_students s
  where s.id=student_id and s.auth_user_id=(select auth.uid())));

create policy "admin manages kite tips" on public.raul_kite_student_tips
for all to authenticated using ((select auth.jwt()->'app_metadata'->>'role')='admin')
with check ((select auth.jwt()->'app_metadata'->>'role')='admin');
create policy "instructors manage own kite tips" on public.raul_kite_student_tips
for all to authenticated using (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active))
with check (owner_id=(select auth.uid()) and (select auth.jwt()->'app_metadata'->>'role')='instructor'
  and exists(select 1 from public.raul_kite_instructors i where i.auth_user_id=(select auth.uid()) and i.is_active));
create policy "students read published tips of own instructor" on public.raul_kite_student_tips
for select to authenticated using (is_published and exists(select 1 from public.raul_kite_students s
  where s.auth_user_id=(select auth.uid()) and s.owner_id=raul_kite_student_tips.owner_id));

-- Keep students from changing the owner_id attached to their own profile.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;
create or replace function private.current_student_owner_id()
returns uuid language sql stable security definer set search_path=''
as $$
 select s.owner_id from public.raul_kite_students s
 where s.auth_user_id=(select auth.uid()) limit 1
$$;
revoke all on function private.current_student_owner_id() from public;
grant execute on function private.current_student_owner_id() to authenticated;
create policy "students update own kite profile" on public.raul_kite_students
for update to authenticated using (auth_user_id=(select auth.uid()))
with check (auth_user_id=(select auth.uid()) and owner_id=(select private.current_student_owner_id()));

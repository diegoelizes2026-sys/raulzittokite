-- Migração incremental da Área do Aluno Raulzito Kite.
-- Projeto Supabase Meniuza. Não remove tabelas, políticas ou registros existentes.
begin;

alter table public.raul_kite_students
  add column if not exists auth_user_id uuid unique references auth.users(id) on delete set null,
  add column if not exists avatar_url text,
  add column if not exists locality text;
alter table public.raul_kite_lessons add column if not exists student_booking boolean not null default false;

create table if not exists public.raul_kite_lesson_types (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null, duration_minutes integer not null default 60 check(duration_minutes between 30 and 240),
 description text, is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.raul_kite_lesson_packages (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null, lesson_count integer not null check(lesson_count>0), price numeric(10,2) not null check(price>=0),
 description text, benefits text, is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.raul_kite_student_purchases (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 student_id uuid not null references public.raul_kite_students(id) on delete cascade,
 package_id uuid not null references public.raul_kite_lesson_packages(id), package_name text not null,
 lessons_quantity integer not null check(lessons_quantity>0), amount numeric(10,2) not null check(amount>=0),
 status text not null default 'pending' check(status in ('pending','confirmed','cancelled')),
 payment_status text not null default 'pending' check(payment_status in ('pending','confirmed','refunded')),
 payment_method text, student_message text, created_at timestamptz not null default now(), confirmed_at timestamptz
);
create table if not exists public.raul_kite_student_credits (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 student_id uuid not null references public.raul_kite_students(id) on delete cascade,
 purchase_id uuid references public.raul_kite_student_purchases(id) on delete restrict,
 lesson_id uuid references public.raul_kite_lessons(id) on delete restrict,
 delta integer not null check(delta<>0), description text not null, created_at timestamptz not null default now(),
 created_by uuid references auth.users(id)
);
create unique index if not exists raul_kite_student_credits_purchase_unique on public.raul_kite_student_credits(purchase_id) where purchase_id is not null;
create unique index if not exists raul_kite_student_credits_lesson_unique on public.raul_kite_student_credits(lesson_id) where lesson_id is not null;

create table if not exists public.raul_kite_student_progress (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 student_id uuid not null references public.raul_kite_students(id) on delete cascade,
 level text, experience text, technical_evolution text, kite_control text, board_control text, balance text, safety text,
 instructor_notes text, next_goals text, is_visible boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.raul_kite_student_tips (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 title text not null, body text not null, media_url text,
 media_type text not null default 'none' check(media_type in ('none','image','video')),
 is_published boolean not null default false, published_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

do $$ begin
 if not exists(select 1 from pg_constraint where conrelid='public.raul_kite_lessons'::regclass and conname='raul_kite_lessons_no_overlap_excl') then
  alter table public.raul_kite_lessons add constraint raul_kite_lessons_no_overlap_excl
  exclude using gist(owner_id with =, lesson_slot with &&) where(status<>'cancelada');
 end if;
end $$;

alter table public.raul_kite_lesson_types enable row level security;
alter table public.raul_kite_lesson_packages enable row level security;
alter table public.raul_kite_student_purchases enable row level security;
alter table public.raul_kite_student_credits enable row level security;
alter table public.raul_kite_student_progress enable row level security;
alter table public.raul_kite_student_tips enable row level security;

-- Instructor access, scoped to the already-existing Raul Auth user.
create policy "Raul manages kite lesson types" on public.raul_kite_lesson_types for all to authenticated
 using(auth.uid()=owner_id and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid)
 with check(auth.uid()=owner_id and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid);
create policy "Students read active kite lesson types" on public.raul_kite_lesson_types for select to authenticated
 using(is_active and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid and exists(select 1 from public.raul_kite_students s where s.auth_user_id=auth.uid() and s.owner_id=public.raul_kite_lesson_types.owner_id));

create policy "Raul manages kite lesson packages" on public.raul_kite_lesson_packages for all to authenticated
 using(auth.uid()=owner_id and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid)
 with check(auth.uid()=owner_id and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid);
create policy "Students read active kite packages" on public.raul_kite_lesson_packages for select to authenticated
 using(is_active and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid and exists(select 1 from public.raul_kite_students s where s.auth_user_id=auth.uid() and s.owner_id=public.raul_kite_lesson_packages.owner_id));

create policy "Raul manages kite purchases" on public.raul_kite_student_purchases for all to authenticated
 using(auth.uid()=owner_id and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid)
 with check(auth.uid()=owner_id and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid);
create policy "Students view own kite purchases" on public.raul_kite_student_purchases for select to authenticated
 using(exists(select 1 from public.raul_kite_students s where s.id=student_id and s.auth_user_id=auth.uid()));
create policy "Students request own kite purchases" on public.raul_kite_student_purchases for insert to authenticated
 with check(owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid and status='pending' and payment_status='pending'
 and exists(select 1 from public.raul_kite_students s where s.id=student_id and s.auth_user_id=auth.uid() and s.owner_id=public.raul_kite_student_purchases.owner_id)
 and exists(select 1 from public.raul_kite_lesson_packages p where p.id=package_id and p.owner_id=public.raul_kite_student_purchases.owner_id and p.is_active and p.lesson_count=lessons_quantity and p.price=amount and p.name=package_name));

create policy "Raul manages kite credits" on public.raul_kite_student_credits for select to authenticated
 using(auth.uid()=owner_id and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid);
create policy "Students view own kite credits" on public.raul_kite_student_credits for select to authenticated
 using(exists(select 1 from public.raul_kite_students s where s.id=student_id and s.auth_user_id=auth.uid()));
create policy "Raul manages kite progress" on public.raul_kite_student_progress for all to authenticated
 using(auth.uid()=owner_id and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid)
 with check(auth.uid()=owner_id and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid);
create policy "Students view published progress" on public.raul_kite_student_progress for select to authenticated
 using(is_visible and exists(select 1 from public.raul_kite_students s where s.id=student_id and s.auth_user_id=auth.uid()));
create policy "Raul manages kite tips" on public.raul_kite_student_tips for all to authenticated
 using(auth.uid()=owner_id and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid)
 with check(auth.uid()=owner_id and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid);
create policy "Students read published kite tips" on public.raul_kite_student_tips for select to authenticated
 using(is_published and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid and exists(select 1 from public.raul_kite_students s where s.auth_user_id=auth.uid() and s.owner_id=public.raul_kite_student_tips.owner_id));

create policy "Students read own kite profile" on public.raul_kite_students for select to authenticated using(auth_user_id=auth.uid());
create policy "Students update own kite profile" on public.raul_kite_students for update to authenticated using(auth_user_id=auth.uid())
 with check(auth_user_id=auth.uid() and owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid);
create policy "Students read own kite lessons" on public.raul_kite_lessons for select to authenticated
 using(exists(select 1 from public.raul_kite_students s where s.id=student_id and s.auth_user_id=auth.uid()));
create policy "Students create own kite bookings" on public.raul_kite_lessons for insert to authenticated
 with check(owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid and status='agendada' and student_booking=true
 and exists(select 1 from public.raul_kite_students s where s.id=student_id and s.auth_user_id=auth.uid() and s.owner_id=public.raul_kite_lessons.owner_id));

-- Guard: alunos só atualizam dados de contato; o trigger interno de Auth pode criar/vincular o próprio perfil.
create or replace function public.raul_kite_guard_student_profile() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid()='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid then if TG_OP='DELETE' then return old; else return new; end if; end if;
 if auth.uid() is null and TG_OP='INSERT' and new.owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid and new.auth_user_id is not null then return new; end if;
 if auth.uid() is null and TG_OP='UPDATE' and old.auth_user_id is null and new.auth_user_id is not null and new.owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid then return new; end if;
 if TG_OP in ('INSERT','DELETE') then raise exception 'Somente o instrutor pode criar ou remover perfis.'; end if;
 if old.auth_user_id is distinct from auth.uid() or new.auth_user_id is distinct from old.auth_user_id or new.owner_id is distinct from old.owner_id
  or new.experience_level is distinct from old.experience_level or new.notes is distinct from old.notes or new.created_at is distinct from old.created_at
 then raise exception 'Você só pode atualizar seus dados de contato.'; end if;
 return new;
end $$;
revoke all on function public.raul_kite_guard_student_profile() from public,anon,authenticated;
create trigger raul_kite_guard_student_profile before insert or update or delete on public.raul_kite_students for each row execute function public.raul_kite_guard_student_profile();

create or replace function public.raul_kite_guard_student_booking() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare st public.raul_kite_students%rowtype; lt public.raul_kite_lesson_types%rowtype;
begin
 if auth.uid()=new.owner_id then return new; end if;
 if new.owner_id<>'0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid then raise exception 'Instrutor inválido.'; end if;
 select * into st from public.raul_kite_students where id=new.student_id and auth_user_id=auth.uid() and owner_id=new.owner_id;
 if not found then raise exception 'Perfil de aluno não encontrado.'; end if;
 select * into lt from public.raul_kite_lesson_types where name=new.lesson_type and owner_id=new.owner_id and is_active;
 if not found then raise exception 'Tipo de aula indisponível.'; end if;
 new.student_name:=st.full_name;new.student_phone:=st.phone;new.student_locality:=st.locality;
 new.student_level:=coalesce(st.experience_level,'iniciante');new.duration_minutes:=lt.duration_minutes;
 new.status:='agendada';new.payment_status:='pendente';new.amount:=null;new.group_size:=1;new.student_booking:=true;return new;
end $$;
revoke all on function public.raul_kite_guard_student_booking() from public,anon,authenticated;
create trigger raul_kite_guard_student_booking before insert on public.raul_kite_lessons for each row execute function public.raul_kite_guard_student_booking();

create or replace function public.raul_kite_available_slots(p_date date,p_duration_minutes integer default 60)
returns table(slot time) language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or not exists(select 1 from public.raul_kite_students s where s.auth_user_id=auth.uid() and s.owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid) then raise exception 'Acesso restrito a alunos cadastrados.'; end if;
 if p_date<current_date or p_duration_minutes not between 30 and 240 then raise exception 'Data ou duração inválida.'; end if;
 return query select t.slot::time from generate_series(0,11) n
 cross join lateral(select (time '07:00'+make_interval(mins=>n*60))::time as slot) t
 where not exists(select 1 from public.raul_kite_lessons l where l.owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid and l.status<>'cancelada'
 and l.lesson_slot && tsrange(p_date+t.slot,p_date+t.slot+make_interval(mins=>p_duration_minutes),'[)')) order by t.slot;
end $$;
revoke all on function public.raul_kite_available_slots(date,integer) from public,anon;
grant execute on function public.raul_kite_available_slots(date,integer) to authenticated;

create or replace function public.raul_kite_grant_purchase_credits() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.status='confirmed' and new.payment_status='confirmed' and (old.status is distinct from new.status or old.payment_status is distinct from new.payment_status) then
  insert into public.raul_kite_student_credits(owner_id,student_id,purchase_id,delta,description,created_by)
  values(new.owner_id,new.student_id,new.id,new.lessons_quantity,'Créditos liberados após confirmação do pagamento: '||new.package_name,new.owner_id) on conflict do nothing;
  new.confirmed_at:=coalesce(new.confirmed_at,now());
 end if;return new;
end $$;
revoke all on function public.raul_kite_grant_purchase_credits() from public,anon,authenticated;
create trigger raul_kite_purchase_credit_trigger before update on public.raul_kite_student_purchases for each row execute function public.raul_kite_grant_purchase_credits();

create or replace function public.raul_kite_debit_completed_lesson() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare saldo integer;
begin
 if new.status='concluida' and old.status is distinct from new.status and new.student_id is not null then
  select coalesce(sum(delta),0) into saldo from public.raul_kite_student_credits where student_id=new.student_id;
  if saldo>0 then insert into public.raul_kite_student_credits(owner_id,student_id,lesson_id,delta,description,created_by)
   values(new.owner_id,new.student_id,new.id,-1,'Crédito utilizado em aula concluída',new.owner_id) on conflict do nothing; end if;
 end if;return new;
end $$;
revoke all on function public.raul_kite_debit_completed_lesson() from public,anon,authenticated;
create trigger raul_kite_lesson_credit_trigger after update of status on public.raul_kite_lessons for each row execute function public.raul_kite_debit_completed_lesson();

create or replace function public.raul_kite_create_student_profile() returns trigger language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare existing_id uuid; phone_value text;
begin
 if new.raw_user_meta_data->>'account_type'='raul_kite_student' then
  select id into existing_id from public.raul_kite_students where owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid and auth_user_id is null and lower(coalesce(email,''))=lower(coalesce(new.email,'')) order by created_at limit 1;
  if existing_id is not null then
   update public.raul_kite_students set auth_user_id=new.id,full_name=coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'),''),full_name),phone=coalesce(nullif(trim(new.raw_user_meta_data->>'phone'),''),phone),updated_at=now() where id=existing_id;
  else
   phone_value:=nullif(trim(new.raw_user_meta_data->>'phone'),'');
   if phone_value is not null and exists(select 1 from public.raul_kite_students s where s.owner_id='0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid and regexp_replace(coalesce(s.phone,''),'\D','','g')=regexp_replace(phone_value,'\D','','g')) then phone_value:=null; end if;
   insert into public.raul_kite_students(owner_id,auth_user_id,full_name,phone,email,experience_level)
   values('0c997ebb-4ac2-4879-9b70-ae410581dea8'::uuid,new.id,coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'),''),'Aluno'),phone_value,new.email,nullif(trim(new.raw_user_meta_data->>'experience_level'),'')) on conflict(auth_user_id) do nothing;
  end if;
 end if;return new;
end $$;
revoke all on function public.raul_kite_create_student_profile() from public,anon,authenticated;
create trigger raul_kite_auth_user_profile after insert on auth.users for each row execute function public.raul_kite_create_student_profile();

grant select,insert,update,delete on public.raul_kite_lesson_types to authenticated;
grant select,insert,update,delete on public.raul_kite_lesson_packages to authenticated;
grant select,insert,update on public.raul_kite_student_purchases to authenticated;
grant select on public.raul_kite_student_credits to authenticated;
grant select,insert,update,delete on public.raul_kite_student_progress to authenticated;
grant select,insert,update,delete on public.raul_kite_student_tips to authenticated;
grant select,insert,update,delete on public.raul_kite_lessons to authenticated;
grant select,insert,update,delete on public.raul_kite_students to authenticated;

commit;
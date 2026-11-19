-- ClassHub database setup for Supabase (PostgreSQL).
-- Run this entire file in Supabase Dashboard > SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'Student',
  role text not null default 'student' check (role in ('student','teacher')),
  class_joined boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.class_settings (
  id integer primary key default 1 check (id = 1),
  class_name text not null default 'ClassHub',
  invite_code text not null
);
insert into public.class_settings(id,class_name,invite_code)
values (1,'ClassHub','CHANGE-THIS-CLASS-CODE')
on conflict (id) do nothing;

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);
create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  details text not null,
  due_date date,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);
create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  file_name text not null,
  storage_path text not null unique,
  uploader_id uuid not null references public.profiles(id),
  uploader_name text not null,
  created_at timestamptz not null default now()
);

create or replace function public.create_profile_for_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  insert into public.profiles(id,full_name) values (new.id, coalesce(new.raw_user_meta_data->>'full_name','Student'))
  on conflict (id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.create_profile_for_new_user();

create or replace function public.join_class(invite_code text)
returns boolean language plpgsql security definer set search_path=public
as $$
declare matched boolean;
begin
  if auth.uid() is null then raise exception 'Please log in first'; end if;
  select (cs.invite_code = join_class.invite_code) into matched from public.class_settings cs where cs.id=1;
  if coalesce(matched,false) is not true then raise exception 'Incorrect class invite code'; end if;
  update public.profiles set class_joined=true where id=auth.uid();
  return true;
end; $$;
revoke all on function public.join_class(text) from public;
grant execute on function public.join_class(text) to authenticated;

alter table public.profiles enable row level security;
alter table public.class_settings enable row level security;
alter table public.announcements enable row level security;
alter table public.assignments enable row level security;
alter table public.notes enable row level security;

drop policy if exists "Members can read profiles" on public.profiles;
create policy "Members can read profiles" on public.profiles for select to authenticated
using (id=auth.uid() or exists(select 1 from public.profiles p where p.id=auth.uid() and p.class_joined));
drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile" on public.profiles for select to authenticated using(id=auth.uid());
drop policy if exists "Members read announcements" on public.announcements;
create policy "Members read announcements" on public.announcements for select to authenticated
using(exists(select 1 from public.profiles p where p.id=auth.uid() and p.class_joined));
drop policy if exists "Teachers post announcements" on public.announcements;
create policy "Teachers post announcements" on public.announcements for insert to authenticated
with check(created_by=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='teacher' and p.class_joined));
drop policy if exists "Members read assignments" on public.assignments;
create policy "Members read assignments" on public.assignments for select to authenticated
using(exists(select 1 from public.profiles p where p.id=auth.uid() and p.class_joined));
drop policy if exists "Teachers post assignments" on public.assignments;
create policy "Teachers post assignments" on public.assignments for insert to authenticated
with check(created_by=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='teacher' and p.class_joined));
drop policy if exists "Members read notes" on public.notes;
create policy "Members read notes" on public.notes for select to authenticated
using(exists(select 1 from public.profiles p where p.id=auth.uid() and p.class_joined));
drop policy if exists "Members upload notes" on public.notes;
create policy "Members upload notes" on public.notes for insert to authenticated
with check(uploader_id=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.class_joined));

-- Private storage bucket for class resources. Members can upload/read only after joining.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('class-files','class-files',false,15728640,
array['application/pdf','image/png','image/jpeg','text/plain','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/msword'])
on conflict (id) do update set public=false,file_size_limit=15728640,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists "Class members read files" on storage.objects;
create policy "Class members read files" on storage.objects for select to authenticated
using(bucket_id='class-files' and exists(select 1 from public.profiles p where p.id=auth.uid() and p.class_joined));
drop policy if exists "Class members upload files" on storage.objects;
create policy "Class members upload files" on storage.objects for insert to authenticated
with check(bucket_id='class-files' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.profiles p where p.id=auth.uid() and p.class_joined));

-- TEACHER SETUP:
-- 1. Create the teacher account through the app first and confirm its email.
-- 2. In Supabase SQL Editor run the statement below, replacing the email:
-- update public.profiles p set role='teacher', class_joined=true
-- from auth.users u where p.id=u.id and u.email='teacher@example.com';
-- Change the class invite code above before sharing it with students.

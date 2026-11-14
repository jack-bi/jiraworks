-- Jira-like task management schema.
--
-- IMPORTANT: The RLS policies in this migration intentionally allow public
-- read/write access for development and testing. Replace them with
-- authenticated, project-scoped policies before using production data.

create extension if not exists pgcrypto;

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  project_key text not null,
  name text not null,
  description text not null default '',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint projects_project_key_format_check
    check (project_key ~ '^[A-Z][A-Z0-9_-]{1,19}$'),
  constraint projects_project_key_unique unique (project_key),
  constraint projects_name_not_blank_check check (btrim(name) <> '')
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  task_key text not null,
  title text not null,
  description text not null default '',
  status text not null default 'TO DO',
  assignee text,
  priority text not null default '一般',
  position integer not null default 0,
  tags text[] not null default '{}'::text[],
  notes text not null default '',
  source text not null default '新增',
  attachments jsonb not null default '[]'::jsonb,
  parent_task_id uuid references public.tasks (id) on delete set null,
  merge_reason text,
  due_at timestamptz,
  completed_at timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tasks_project_task_key_unique unique (project_id, task_key),
  constraint tasks_task_key_not_blank_check check (btrim(task_key) <> ''),
  constraint tasks_title_not_blank_check check (btrim(title) <> ''),
  constraint tasks_status_check check (
    status in (
      '暫不處理', '待討論', 'REOPEN', 'TO DO', '問題查詢中',
      'IT 開發', '開發中', '測試中', '開發完成'
    )
  ),
  constraint tasks_priority_check check (
    priority in ('許願', '一般', '高級', '緊急')
  ),
  constraint tasks_position_nonnegative_check check (position >= 0),
  constraint tasks_source_check check (source in ('截圖', '新增', '匯入')),
  constraint tasks_attachments_array_check check (jsonb_typeof(attachments) = 'array'),
  constraint tasks_cannot_parent_itself_check check (parent_task_id is distinct from id)
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks (id) on delete cascade,
  body text not null,
  author_id uuid references auth.users (id) on delete set null,
  author_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint comments_body_not_blank_check check (btrim(body) <> '')
);

create index tasks_project_status_position_idx
  on public.tasks (project_id, status, position);

create index tasks_project_priority_idx
  on public.tasks (project_id, priority);

create index tasks_assignee_idx
  on public.tasks (assignee)
  where assignee is not null;

create index tasks_parent_task_id_idx
  on public.tasks (parent_task_id)
  where parent_task_id is not null;

create index tasks_tags_gin_idx
  on public.tasks using gin (tags);

create index comments_task_created_at_idx
  on public.comments (task_id, created_at);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger projects_set_updated_at
before update on public.projects
for each row execute function public.set_updated_at();

create trigger tasks_set_updated_at
before update on public.tasks
for each row execute function public.set_updated_at();

create trigger comments_set_updated_at
before update on public.comments
for each row execute function public.set_updated_at();

alter table public.projects enable row level security;
alter table public.tasks enable row level security;
alter table public.comments enable row level security;

-- TEST ONLY: anonymous and signed-in clients can perform all operations.
create policy "test_public_all_projects"
on public.projects
for all
to anon, authenticated
using (true)
with check (true);

create policy "test_public_all_tasks"
on public.tasks
for all
to anon, authenticated
using (true)
with check (true);

create policy "test_public_all_comments"
on public.comments
for all
to anon, authenticated
using (true)
with check (true);

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.projects to anon, authenticated;
grant select, insert, update, delete on public.tasks to anon, authenticated;
grant select, insert, update, delete on public.comments to anon, authenticated;

-- Include complete previous rows in Realtime UPDATE and DELETE payloads.
alter table public.projects replica identity full;
alter table public.tasks replica identity full;
alter table public.comments replica identity full;

-- Supabase normally creates this publication before project migrations run.
-- The guard keeps this migration usable in a plain PostgreSQL database too.
do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    alter publication supabase_realtime
      add table public.projects, public.tasks, public.comments;
  else
    raise notice 'supabase_realtime publication not found; skipping Realtime registration';
  end if;
end;
$$;

comment on table public.projects is
  'Task-management projects. RLS policies are intentionally public for testing.';
comment on table public.tasks is
  'Jira-like tasks with board status, priority, assignee, ordering and merge metadata.';
comment on column public.tasks.attachments is
  'Attachment metadata only; binary files should be stored in Supabase Storage.';
comment on column public.tasks.parent_task_id is
  'Optional master task used by the current UI when duplicate tasks are merged.';
comment on table public.comments is
  'Comments and activity notes attached to tasks.';

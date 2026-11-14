-- Shared image storage for the GitHub Pages task board.
--
-- The current application has no user sign-in yet, so these policies mirror
-- the existing development-only anonymous access used by projects/tasks.
-- Replace them with authenticated, owner-scoped policies before storing
-- private or work data.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'task-images',
  'task-images',
  false,
  8000000,
  array['image/png', 'image/jpeg', 'image/webp', 'image/gif']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "test_public_read_task_images" on storage.objects;
create policy "test_public_read_task_images"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'task-images'
  and (storage.foldername(name))[1] = 'images'
);

drop policy if exists "test_public_upload_task_images" on storage.objects;
create policy "test_public_upload_task_images"
on storage.objects
for insert
to anon, authenticated
with check (
  bucket_id = 'task-images'
  and (storage.foldername(name))[1] = 'images'
);

drop policy if exists "test_public_update_task_images" on storage.objects;
create policy "test_public_update_task_images"
on storage.objects
for update
to anon, authenticated
using (
  bucket_id = 'task-images'
  and (storage.foldername(name))[1] = 'images'
)
with check (
  bucket_id = 'task-images'
  and (storage.foldername(name))[1] = 'images'
);

drop policy if exists "test_public_delete_task_images" on storage.objects;
create policy "test_public_delete_task_images"
on storage.objects
for delete
to anon, authenticated
using (
  bucket_id = 'task-images'
  and (storage.foldername(name))[1] = 'images'
);

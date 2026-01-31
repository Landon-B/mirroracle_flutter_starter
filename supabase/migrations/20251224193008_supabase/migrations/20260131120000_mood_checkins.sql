create table "public"."mood_checkins" (
  "id" uuid not null default gen_random_uuid(),
  "user_id" uuid not null,
  "created_at" timestamp with time zone not null default now(),
  "mood_score" integer not null,
  "tags" text[],
  "note" text,
  "source" text,
  "context" text
);

alter table "public"."mood_checkins" enable row level security;

create index mood_checkins_user_created_idx on public.mood_checkins using btree (user_id, created_at desc);

alter table "public"."mood_checkins"
  add constraint "mood_checkins_pkey" primary key (id);

alter table "public"."mood_checkins"
  add constraint "mood_checkins_user_id_fkey" foreign key (user_id)
  references auth.users(id) on delete cascade not valid;

alter table "public"."mood_checkins" validate constraint "mood_checkins_user_id_fkey";

alter table "public"."mood_checkins"
  add constraint "mood_checkins_mood_score_range" check (mood_score between 1 and 5);

create policy "mood_checkins_select_own"
  on "public"."mood_checkins"
  for select
  using (auth.uid() = user_id);

create policy "mood_checkins_insert_own"
  on "public"."mood_checkins"
  for insert
  with check (auth.uid() = user_id);

create policy "mood_checkins_update_own"
  on "public"."mood_checkins"
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "mood_checkins_delete_own"
  on "public"."mood_checkins"
  for delete
  using (auth.uid() = user_id);

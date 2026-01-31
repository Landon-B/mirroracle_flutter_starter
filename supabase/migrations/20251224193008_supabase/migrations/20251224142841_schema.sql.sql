
  create table "public"."affirmations" (
    "id" uuid not null default gen_random_uuid(),
    "text" text not null,
    "category" text default 'general'::text,
    "locale" text default 'en-US'::text,
    "active" boolean not null default true,
    "created_at" timestamp with time zone not null default now(),
    "theme_id" uuid
      );


alter table "public"."affirmations" enable row level security;


  create table "public"."daily_streak_snapshots" (
    "user_id" uuid not null,
    "date" date not null,
    "had_completed_session" boolean not null default true,
    "primary_session_id" uuid,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."device_push_tokens" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "platform" text not null,
    "token" text not null,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );



  create table "public"."favorite_affirmations" (
    "user_id" uuid not null,
    "affirmation_id" uuid not null,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."reminder_settings" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "type" text not null,
    "schedule_mode" text not null,
    "time_of_day" time without time zone not null,
    "enabled" boolean not null default true,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );



  create table "public"."session_affirmations" (
    "id" uuid not null default gen_random_uuid(),
    "session_id" uuid not null,
    "affirmation_id" uuid not null,
    "order_index" integer not null,
    "reps_target" integer not null default 3,
    "reps_completed" integer not null default 0,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );



  create table "public"."sessions" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "started_at" timestamp with time zone not null default now(),
    "duration_s" integer not null default 0,
    "presence_score" real not null default 0,
    "aff_count" integer not null default 3,
    "emotion_tag" text,
    "completed" boolean not null default true,
    "aff_texts" text[],
    "ended_at" timestamp with time zone,
    "presence_seconds" integer,
    "eye_contact_seconds" integer,
    "smiles_count" integer,
    "notes" text,
    "presence_algo_version" text,
    "presence_components" jsonb,
    "theme_id" uuid,
    "session_type" text,
    "mode" text,
    "device_local_date" date,
    "reps_target" integer not null default 9,
    "reps_completed" integer not null default 0,
    "halo_unlocked" boolean not null default false
      );


alter table "public"."sessions" enable row level security;


  create table "public"."themes" (
    "id" uuid not null default gen_random_uuid(),
    "code" text not null,
    "name" text not null,
    "description" text,
    "is_premium" boolean not null default false,
    "sort_order" integer not null default 0,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );



  create table "public"."user_theme_preferences" (
    "user_id" uuid not null,
    "theme_id" uuid not null,
    "strength" integer not null default 1,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


CREATE UNIQUE INDEX affirmations_pkey ON public.affirmations USING btree (id);

CREATE UNIQUE INDEX daily_streak_snapshots_pkey ON public.daily_streak_snapshots USING btree (user_id, date);

CREATE UNIQUE INDEX device_push_tokens_pkey ON public.device_push_tokens USING btree (id);

CREATE UNIQUE INDEX favorite_affirmations_pkey ON public.favorite_affirmations USING btree (user_id, affirmation_id);

CREATE UNIQUE INDEX reminder_settings_pkey ON public.reminder_settings USING btree (id);

CREATE UNIQUE INDEX session_affirmations_pkey ON public.session_affirmations USING btree (id);

CREATE UNIQUE INDEX session_affirmations_unique_session_order ON public.session_affirmations USING btree (session_id, order_index);

CREATE UNIQUE INDEX sessions_pkey ON public.sessions USING btree (id);

CREATE INDEX sessions_started_idx ON public.sessions USING btree (started_at);

CREATE INDEX sessions_user_idx ON public.sessions USING btree (user_id);

CREATE INDEX sessions_user_started_idx ON public.sessions USING btree (user_id, started_at DESC);

CREATE UNIQUE INDEX themes_code_key ON public.themes USING btree (code);

CREATE UNIQUE INDEX themes_pkey ON public.themes USING btree (id);

CREATE UNIQUE INDEX user_theme_preferences_pkey ON public.user_theme_preferences USING btree (user_id, theme_id);

alter table "public"."affirmations" add constraint "affirmations_pkey" PRIMARY KEY using index "affirmations_pkey";

alter table "public"."daily_streak_snapshots" add constraint "daily_streak_snapshots_pkey" PRIMARY KEY using index "daily_streak_snapshots_pkey";

alter table "public"."device_push_tokens" add constraint "device_push_tokens_pkey" PRIMARY KEY using index "device_push_tokens_pkey";

alter table "public"."favorite_affirmations" add constraint "favorite_affirmations_pkey" PRIMARY KEY using index "favorite_affirmations_pkey";

alter table "public"."reminder_settings" add constraint "reminder_settings_pkey" PRIMARY KEY using index "reminder_settings_pkey";

alter table "public"."session_affirmations" add constraint "session_affirmations_pkey" PRIMARY KEY using index "session_affirmations_pkey";

alter table "public"."sessions" add constraint "sessions_pkey" PRIMARY KEY using index "sessions_pkey";

alter table "public"."themes" add constraint "themes_pkey" PRIMARY KEY using index "themes_pkey";

alter table "public"."user_theme_preferences" add constraint "user_theme_preferences_pkey" PRIMARY KEY using index "user_theme_preferences_pkey";

alter table "public"."affirmations" add constraint "affirmations_theme_id_fkey" FOREIGN KEY (theme_id) REFERENCES public.themes(id) not valid;

alter table "public"."affirmations" validate constraint "affirmations_theme_id_fkey";

alter table "public"."daily_streak_snapshots" add constraint "daily_streak_snapshots_primary_session_id_fkey" FOREIGN KEY (primary_session_id) REFERENCES public.sessions(id) not valid;

alter table "public"."daily_streak_snapshots" validate constraint "daily_streak_snapshots_primary_session_id_fkey";

alter table "public"."daily_streak_snapshots" add constraint "daily_streak_snapshots_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."daily_streak_snapshots" validate constraint "daily_streak_snapshots_user_id_fkey";

alter table "public"."device_push_tokens" add constraint "device_push_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."device_push_tokens" validate constraint "device_push_tokens_user_id_fkey";

alter table "public"."favorite_affirmations" add constraint "favorite_affirmations_affirmation_id_fkey" FOREIGN KEY (affirmation_id) REFERENCES public.affirmations(id) ON DELETE CASCADE not valid;

alter table "public"."favorite_affirmations" validate constraint "favorite_affirmations_affirmation_id_fkey";

alter table "public"."favorite_affirmations" add constraint "favorite_affirmations_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."favorite_affirmations" validate constraint "favorite_affirmations_user_id_fkey";

alter table "public"."reminder_settings" add constraint "reminder_settings_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."reminder_settings" validate constraint "reminder_settings_user_id_fkey";

alter table "public"."session_affirmations" add constraint "session_affirmations_affirmation_id_fkey" FOREIGN KEY (affirmation_id) REFERENCES public.affirmations(id) not valid;

alter table "public"."session_affirmations" validate constraint "session_affirmations_affirmation_id_fkey";

alter table "public"."session_affirmations" add constraint "session_affirmations_session_id_fkey" FOREIGN KEY (session_id) REFERENCES public.sessions(id) ON DELETE CASCADE not valid;

alter table "public"."session_affirmations" validate constraint "session_affirmations_session_id_fkey";

alter table "public"."session_affirmations" add constraint "session_affirmations_unique_session_order" UNIQUE using index "session_affirmations_unique_session_order";

alter table "public"."sessions" add constraint "sessions_presence_score_0_1" CHECK (((presence_score >= (0)::double precision) AND (presence_score <= (1)::double precision))) NOT VALID not valid;

alter table "public"."sessions" validate constraint "sessions_presence_score_0_1";

alter table "public"."sessions" add constraint "sessions_theme_id_fkey" FOREIGN KEY (theme_id) REFERENCES public.themes(id) not valid;

alter table "public"."sessions" validate constraint "sessions_theme_id_fkey";

alter table "public"."sessions" add constraint "sessions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."sessions" validate constraint "sessions_user_id_fkey";

alter table "public"."themes" add constraint "themes_code_key" UNIQUE using index "themes_code_key";

alter table "public"."user_theme_preferences" add constraint "user_theme_preferences_theme_id_fkey" FOREIGN KEY (theme_id) REFERENCES public.themes(id) ON DELETE CASCADE not valid;

alter table "public"."user_theme_preferences" validate constraint "user_theme_preferences_theme_id_fkey";

alter table "public"."user_theme_preferences" add constraint "user_theme_preferences_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."user_theme_preferences" validate constraint "user_theme_preferences_user_id_fkey";

set check_function_bodies = off;

drop function if exists public.random_affirmations(integer);

create function public.random_affirmations(p_limit integer)
 returns table(
  id uuid,
  text text,
  category text,
  locale text,
  active boolean,
  created_at timestamp with time zone,
  theme_id uuid,
  theme_name text
 )
 language sql
 stable
as $function$
  select
    a.id,
    a.text,
    a.category,
    a.locale,
    a.active,
    a.created_at,
    a.theme_id,
    t.name as theme_name
  from public.affirmations a
  left join public.themes t on t.id = a.theme_id
  where a.active = true
  order by random()
  limit p_limit;
$function$
;

grant delete on table "public"."affirmations" to "anon";

grant insert on table "public"."affirmations" to "anon";

grant references on table "public"."affirmations" to "anon";

grant select on table "public"."affirmations" to "anon";

grant trigger on table "public"."affirmations" to "anon";

grant truncate on table "public"."affirmations" to "anon";

grant update on table "public"."affirmations" to "anon";

grant delete on table "public"."affirmations" to "authenticated";

grant insert on table "public"."affirmations" to "authenticated";

grant references on table "public"."affirmations" to "authenticated";

grant select on table "public"."affirmations" to "authenticated";

grant trigger on table "public"."affirmations" to "authenticated";

grant truncate on table "public"."affirmations" to "authenticated";

grant update on table "public"."affirmations" to "authenticated";

grant delete on table "public"."affirmations" to "service_role";

grant insert on table "public"."affirmations" to "service_role";

grant references on table "public"."affirmations" to "service_role";

grant select on table "public"."affirmations" to "service_role";

grant trigger on table "public"."affirmations" to "service_role";

grant truncate on table "public"."affirmations" to "service_role";

grant update on table "public"."affirmations" to "service_role";

grant delete on table "public"."daily_streak_snapshots" to "anon";

grant insert on table "public"."daily_streak_snapshots" to "anon";

grant references on table "public"."daily_streak_snapshots" to "anon";

grant select on table "public"."daily_streak_snapshots" to "anon";

grant trigger on table "public"."daily_streak_snapshots" to "anon";

grant truncate on table "public"."daily_streak_snapshots" to "anon";

grant update on table "public"."daily_streak_snapshots" to "anon";

grant delete on table "public"."daily_streak_snapshots" to "authenticated";

grant insert on table "public"."daily_streak_snapshots" to "authenticated";

grant references on table "public"."daily_streak_snapshots" to "authenticated";

grant select on table "public"."daily_streak_snapshots" to "authenticated";

grant trigger on table "public"."daily_streak_snapshots" to "authenticated";

grant truncate on table "public"."daily_streak_snapshots" to "authenticated";

grant update on table "public"."daily_streak_snapshots" to "authenticated";

grant delete on table "public"."daily_streak_snapshots" to "service_role";

grant insert on table "public"."daily_streak_snapshots" to "service_role";

grant references on table "public"."daily_streak_snapshots" to "service_role";

grant select on table "public"."daily_streak_snapshots" to "service_role";

grant trigger on table "public"."daily_streak_snapshots" to "service_role";

grant truncate on table "public"."daily_streak_snapshots" to "service_role";

grant update on table "public"."daily_streak_snapshots" to "service_role";

grant delete on table "public"."device_push_tokens" to "anon";

grant insert on table "public"."device_push_tokens" to "anon";

grant references on table "public"."device_push_tokens" to "anon";

grant select on table "public"."device_push_tokens" to "anon";

grant trigger on table "public"."device_push_tokens" to "anon";

grant truncate on table "public"."device_push_tokens" to "anon";

grant update on table "public"."device_push_tokens" to "anon";

grant delete on table "public"."device_push_tokens" to "authenticated";

grant insert on table "public"."device_push_tokens" to "authenticated";

grant references on table "public"."device_push_tokens" to "authenticated";

grant select on table "public"."device_push_tokens" to "authenticated";

grant trigger on table "public"."device_push_tokens" to "authenticated";

grant truncate on table "public"."device_push_tokens" to "authenticated";

grant update on table "public"."device_push_tokens" to "authenticated";

grant delete on table "public"."device_push_tokens" to "service_role";

grant insert on table "public"."device_push_tokens" to "service_role";

grant references on table "public"."device_push_tokens" to "service_role";

grant select on table "public"."device_push_tokens" to "service_role";

grant trigger on table "public"."device_push_tokens" to "service_role";

grant truncate on table "public"."device_push_tokens" to "service_role";

grant update on table "public"."device_push_tokens" to "service_role";

grant delete on table "public"."favorite_affirmations" to "anon";

grant insert on table "public"."favorite_affirmations" to "anon";

grant references on table "public"."favorite_affirmations" to "anon";

grant select on table "public"."favorite_affirmations" to "anon";

grant trigger on table "public"."favorite_affirmations" to "anon";

grant truncate on table "public"."favorite_affirmations" to "anon";

grant update on table "public"."favorite_affirmations" to "anon";

grant delete on table "public"."favorite_affirmations" to "authenticated";

grant insert on table "public"."favorite_affirmations" to "authenticated";

grant references on table "public"."favorite_affirmations" to "authenticated";

grant select on table "public"."favorite_affirmations" to "authenticated";

grant trigger on table "public"."favorite_affirmations" to "authenticated";

grant truncate on table "public"."favorite_affirmations" to "authenticated";

grant update on table "public"."favorite_affirmations" to "authenticated";

grant delete on table "public"."favorite_affirmations" to "service_role";

grant insert on table "public"."favorite_affirmations" to "service_role";

grant references on table "public"."favorite_affirmations" to "service_role";

grant select on table "public"."favorite_affirmations" to "service_role";

grant trigger on table "public"."favorite_affirmations" to "service_role";

grant truncate on table "public"."favorite_affirmations" to "service_role";

grant update on table "public"."favorite_affirmations" to "service_role";

grant delete on table "public"."reminder_settings" to "anon";

grant insert on table "public"."reminder_settings" to "anon";

grant references on table "public"."reminder_settings" to "anon";

grant select on table "public"."reminder_settings" to "anon";

grant trigger on table "public"."reminder_settings" to "anon";

grant truncate on table "public"."reminder_settings" to "anon";

grant update on table "public"."reminder_settings" to "anon";

grant delete on table "public"."reminder_settings" to "authenticated";

grant insert on table "public"."reminder_settings" to "authenticated";

grant references on table "public"."reminder_settings" to "authenticated";

grant select on table "public"."reminder_settings" to "authenticated";

grant trigger on table "public"."reminder_settings" to "authenticated";

grant truncate on table "public"."reminder_settings" to "authenticated";

grant update on table "public"."reminder_settings" to "authenticated";

grant delete on table "public"."reminder_settings" to "service_role";

grant insert on table "public"."reminder_settings" to "service_role";

grant references on table "public"."reminder_settings" to "service_role";

grant select on table "public"."reminder_settings" to "service_role";

grant trigger on table "public"."reminder_settings" to "service_role";

grant truncate on table "public"."reminder_settings" to "service_role";

grant update on table "public"."reminder_settings" to "service_role";

grant delete on table "public"."session_affirmations" to "anon";

grant insert on table "public"."session_affirmations" to "anon";

grant references on table "public"."session_affirmations" to "anon";

grant select on table "public"."session_affirmations" to "anon";

grant trigger on table "public"."session_affirmations" to "anon";

grant truncate on table "public"."session_affirmations" to "anon";

grant update on table "public"."session_affirmations" to "anon";

grant delete on table "public"."session_affirmations" to "authenticated";

grant insert on table "public"."session_affirmations" to "authenticated";

grant references on table "public"."session_affirmations" to "authenticated";

grant select on table "public"."session_affirmations" to "authenticated";

grant trigger on table "public"."session_affirmations" to "authenticated";

grant truncate on table "public"."session_affirmations" to "authenticated";

grant update on table "public"."session_affirmations" to "authenticated";

grant delete on table "public"."session_affirmations" to "service_role";

grant insert on table "public"."session_affirmations" to "service_role";

grant references on table "public"."session_affirmations" to "service_role";

grant select on table "public"."session_affirmations" to "service_role";

grant trigger on table "public"."session_affirmations" to "service_role";

grant truncate on table "public"."session_affirmations" to "service_role";

grant update on table "public"."session_affirmations" to "service_role";

grant delete on table "public"."sessions" to "anon";

grant insert on table "public"."sessions" to "anon";

grant references on table "public"."sessions" to "anon";

grant select on table "public"."sessions" to "anon";

grant trigger on table "public"."sessions" to "anon";

grant truncate on table "public"."sessions" to "anon";

grant update on table "public"."sessions" to "anon";

grant delete on table "public"."sessions" to "authenticated";

grant insert on table "public"."sessions" to "authenticated";

grant references on table "public"."sessions" to "authenticated";

grant select on table "public"."sessions" to "authenticated";

grant trigger on table "public"."sessions" to "authenticated";

grant truncate on table "public"."sessions" to "authenticated";

grant update on table "public"."sessions" to "authenticated";

grant delete on table "public"."sessions" to "service_role";

grant insert on table "public"."sessions" to "service_role";

grant references on table "public"."sessions" to "service_role";

grant select on table "public"."sessions" to "service_role";

grant trigger on table "public"."sessions" to "service_role";

grant truncate on table "public"."sessions" to "service_role";

grant update on table "public"."sessions" to "service_role";

grant delete on table "public"."themes" to "anon";

grant insert on table "public"."themes" to "anon";

grant references on table "public"."themes" to "anon";

grant select on table "public"."themes" to "anon";

grant trigger on table "public"."themes" to "anon";

grant truncate on table "public"."themes" to "anon";

grant update on table "public"."themes" to "anon";

grant delete on table "public"."themes" to "authenticated";

grant insert on table "public"."themes" to "authenticated";

grant references on table "public"."themes" to "authenticated";

grant select on table "public"."themes" to "authenticated";

grant trigger on table "public"."themes" to "authenticated";

grant truncate on table "public"."themes" to "authenticated";

grant update on table "public"."themes" to "authenticated";

grant delete on table "public"."themes" to "service_role";

grant insert on table "public"."themes" to "service_role";

grant references on table "public"."themes" to "service_role";

grant select on table "public"."themes" to "service_role";

grant trigger on table "public"."themes" to "service_role";

grant truncate on table "public"."themes" to "service_role";

grant update on table "public"."themes" to "service_role";

grant delete on table "public"."user_theme_preferences" to "anon";

grant insert on table "public"."user_theme_preferences" to "anon";

grant references on table "public"."user_theme_preferences" to "anon";

grant select on table "public"."user_theme_preferences" to "anon";

grant trigger on table "public"."user_theme_preferences" to "anon";

grant truncate on table "public"."user_theme_preferences" to "anon";

grant update on table "public"."user_theme_preferences" to "anon";

grant delete on table "public"."user_theme_preferences" to "authenticated";

grant insert on table "public"."user_theme_preferences" to "authenticated";

grant references on table "public"."user_theme_preferences" to "authenticated";

grant select on table "public"."user_theme_preferences" to "authenticated";

grant trigger on table "public"."user_theme_preferences" to "authenticated";

grant truncate on table "public"."user_theme_preferences" to "authenticated";

grant update on table "public"."user_theme_preferences" to "authenticated";

grant delete on table "public"."user_theme_preferences" to "service_role";

grant insert on table "public"."user_theme_preferences" to "service_role";

grant references on table "public"."user_theme_preferences" to "service_role";

grant select on table "public"."user_theme_preferences" to "service_role";

grant trigger on table "public"."user_theme_preferences" to "service_role";

grant truncate on table "public"."user_theme_preferences" to "service_role";

grant update on table "public"."user_theme_preferences" to "service_role";


  create policy "affirmations_read"
  on "public"."affirmations"
  as permissive
  for select
  to authenticated
using (active);



  create policy "affirmations_write"
  on "public"."affirmations"
  as permissive
  for all
  to service_role
using (true)
with check (true);



  create policy "Users can manage their own sessions"
  on "public"."sessions"
  as permissive
  for all
  to public
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "users can insert own sessions"
  on "public"."sessions"
  as permissive
  for insert
  to authenticated
with check ((auth.uid() = user_id));



  create policy "users can update own sessions"
  on "public"."sessions"
  as permissive
  for update
  to authenticated
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));



  create policy "users can view own sessions"
  on "public"."sessions"
  as permissive
  for select
  to authenticated
using ((auth.uid() = user_id));



-- Affirmations table + RLS + seed

create extension if not exists pgcrypto;

create table if not exists public.affirmations (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  category text default 'general',
  locale text default 'en-US',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.affirmations enable row level security;

drop policy if exists "affirmations_read" on public.affirmations;
create policy "affirmations_read"
on public.affirmations for select
to authenticated
using (active);

-- service_role can mutate via server - client apps read only
drop policy if exists "affirmations_write" on public.affirmations;
create policy "affirmations_write"
on public.affirmations for all
to service_role
using (true)
with check (true);

-- Seed 100 rows
insert into public.affirmations (text, category, locale, active) values
("I am grounded and present.", 'general', 'en-US', true),
("I breathe in calm and exhale tension.", 'general', 'en-US', true),
("I deserve good things.", 'general', 'en-US', true),
("I am capable and resourceful.", 'general', 'en-US', true),
("I keep promises to myself.", 'general', 'en-US', true),
("I am consistent even when it\u2019s hard.", 'general', 'en-US', true),
("I choose progress over perfection.", 'general', 'en-US', true),
("I trust my timing.", 'general', 'en-US', true),
("I am proud of who I\u2019m becoming.", 'general', 'en-US', true),
("I honor my boundaries.", 'general', 'en-US', true),
("I speak to myself with kindness.", 'general', 'en-US', true),
("I can do hard things.", 'general', 'en-US', true),
("I am safe to take up space.", 'general', 'en-US', true),
("I learn fast and adapt.", 'general', 'en-US', true),
("I am worthy of love as I am.", 'general', 'en-US', true),
("I am focused and deliberate.", 'general', 'en-US', true),
("I move with purpose.", 'general', 'en-US', true),
("I finish what I start.", 'general', 'en-US', true),
("I follow through.", 'general', 'en-US', true),
("I am patient with my growth.", 'general', 'en-US', true),
("I am resilient and creative.", 'general', 'en-US', true),
("I show up today.", 'general', 'en-US', true),
("I keep going.", 'general', 'en-US', true),
("I am allowed to rest.", 'general', 'en-US', true),
("I release what I can\u2019t control.", 'general', 'en-US', true),
("I trust myself to figure it out.", 'general', 'en-US', true),
("I am disciplined and joyful.", 'general', 'en-US', true),
("I build habits that serve me.", 'general', 'en-US', true),
("I am grateful for this moment.", 'general', 'en-US', true),
("I am courageous today.", 'general', 'en-US', true),
("I am enough.", 'general', 'en-US', true),
("I have everything I need to begin.", 'general', 'en-US', true),
("I let go of comparison.", 'general', 'en-US', true),
("I am open to guidance.", 'general', 'en-US', true),
("I am becoming my best self.", 'general', 'en-US', true),
("I choose clarity.", 'general', 'en-US', true),
("I choose to start now.", 'general', 'en-US', true),
("I honor small wins.", 'general', 'en-US', true),
("I make aligned choices.", 'general', 'en-US', true),
("I take the next right step.", 'general', 'en-US', true),
("I am gentle and strong.", 'general', 'en-US', true),
("I am improving daily.", 'general', 'en-US', true),
("I focus on what matters.", 'general', 'en-US', true),
("I am present in my body.", 'general', 'en-US', true),
("I forgive my past self.", 'general', 'en-US', true),
("I celebrate my effort.", 'general', 'en-US', true),
("I build momentum.", 'general', 'en-US', true),
("I make time for what I value.", 'general', 'en-US', true),
("I listen to my inner wisdom.", 'general', 'en-US', true),
("I trust my process.", 'general', 'en-US', true),
("I am steady under pressure.", 'general', 'en-US', true),
("I give myself permission to succeed.", 'general', 'en-US', true),
("I am resilient in setbacks.", 'general', 'en-US', true),
("I attract supportive people.", 'general', 'en-US', true),
("I am calm and confident.", 'general', 'en-US', true),
("I am worthy of opportunities.", 'general', 'en-US', true),
("I am focused on solutions.", 'general', 'en-US', true),
("I take ownership.", 'general', 'en-US', true),
("I show up as myself.", 'general', 'en-US', true),
("I am proud of my progress.", 'general', 'en-US', true),
("I keep learning.", 'general', 'en-US', true),
("I act with integrity.", 'general', 'en-US', true),
("I am brave enough to begin.", 'general', 'en-US', true),
("I move one step at a time.", 'general', 'en-US', true),
("I choose habits over motivation.", 'general', 'en-US', true),
("I let go of perfectionism.", 'general', 'en-US', true),
("I am resourceful in any situation.", 'general', 'en-US', true),
("I respect my energy.", 'general', 'en-US', true),
("I am clear and decisive.", 'general', 'en-US', true),
("I am grateful for my body.", 'general', 'en-US', true),
("I trust my intuition.", 'general', 'en-US', true),
("I choose to believe in me.", 'general', 'en-US', true),
("I am consistent and committed.", 'general', 'en-US', true),
("I make space for joy.", 'general', 'en-US', true),
("I am worthy of rest and success.", 'general', 'en-US', true),
("I can change my mind.", 'general', 'en-US', true),
("I am aligned with my purpose.", 'general', 'en-US', true),
("I honor my commitments.", 'general', 'en-US', true),
("I am calm in uncertainty.", 'general', 'en-US', true),
("I am becoming more confident.", 'general', 'en-US', true),
("I own my story.", 'general', 'en-US', true),
("I am patient and persistent.", 'general', 'en-US', true),
("I am proud of today\u2019s effort.", 'general', 'en-US', true),
("I am expanding my capacity.", 'general', 'en-US', true),
("I am present and attentive.", 'general', 'en-US', true),
("I am disciplined with my time.", 'general', 'en-US', true),
("I choose courage over comfort.", 'general', 'en-US', true),
("I accept myself completely.", 'general', 'en-US', true),
("I prioritize what matters most.", 'general', 'en-US', true),
("I am stronger than my excuses.", 'general', 'en-US', true),
("I follow my plan.", 'general', 'en-US', true),
("I am creating the life I want.", 'general', 'en-US', true),
("I choose faith over fear.", 'general', 'en-US', true),
("I am grateful for the lesson.", 'general', 'en-US', true),
("I am in charge of my actions.", 'general', 'en-US', true),
("I am building trust with myself.", 'general', 'en-US', true),
("I am flexible and focused.", 'general', 'en-US', true),
("I honor my word to myself.", 'general', 'en-US', true),
("I bring value wherever I go.", 'general', 'en-US', true),
("I am ready for the next step.", 'general', 'en-US', true);

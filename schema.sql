-- Run this once in Supabase: SQL Editor > New query > paste > Run.

create table public.site_content (
  id int primary key default 1 check (id = 1),
  data jsonb not null,
  updated_at timestamptz not null default now()
);
create table public.admins (user_id uuid primary key references auth.users(id) on delete cascade);
create table public.messages (
  id bigint generated always as identity primary key,
  name text, email text, message text, ip_hash text,
  created_at timestamptz not null default now()
);
create index on public.messages (ip_hash, created_at);

alter table public.site_content enable row level security;
alter table public.admins enable row level security;
alter table public.messages enable row level security;

create function public.is_admin() returns boolean
  language sql stable security definer set search_path = public
  as $$ select exists (select 1 from public.admins where user_id = auth.uid()) $$;

-- anyone can read site content; only admins can change it
create policy "public read" on public.site_content for select using (true);
create policy "admin write" on public.site_content for all using (public.is_admin()) with check (public.is_admin());
-- admins table: no policies = not reachable from the API at all
create policy "admin read messages" on public.messages for select using (public.is_admin());

-- image bucket: public read, admin-only write, 3 MB, images only (no SVG)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 3145728, array['image/png','image/jpeg','image/webp','image/gif'])
on conflict (id) do nothing;
create policy "media public read" on storage.objects for select using (bucket_id = 'media');
create policy "media admin insert" on storage.objects for insert with check (bucket_id = 'media' and public.is_admin());
create policy "media admin update" on storage.objects for update using (bucket_id = 'media' and public.is_admin());
create policy "media admin delete" on storage.objects for delete using (bucket_id = 'media' and public.is_admin());

-- starting content (edit everything later from admin.html)
insert into public.site_content (id, data) values (1, $json$
{
 "name":"Taha H. Alkhawtani","role":"Software Engineer","location":"Medina, Saudi Arabia","photo":"./pfp.jpeg","email":"taha@taha-k.dev",
 "words":["systems","languages","games","tools"],
 "bio":["Software engineering student interested in systems programming, programming languages, game development and developer tools.","I like working close to the machine: lexers, parsers, memory, runtimes, and the tools that make developers faster."],
 "philosophy":"Understand the layer below the one you work in. Build it yourself at least once.",
 "links":[{"label":"GitHub","url":"https://github.com/TA2x"},{"label":"LinkedIn","url":"https://www.linkedin.com/in/taha-h-alkhawtani/"},{"label":"X","url":"https://x.com/TahaMakes_0"}],
 "projects":[
  {"id":"tara","title":"Tara","category":"Language","status":"in-progress","featured":true,"published":true,"summary":"My own programming language, written in Rust.","details":"Currently has a lexer and parser. A compiler and a virtual machine are planned.","roadmap":[{"l":"Lexer","d":true},{"l":"Parser","d":true},{"l":"Compiler","d":false},{"l":"Virtual machine","d":false}],"tech":["Rust","Compilers","Parsing"],"links":[],"image":""},
  {"id":"taskforge","title":"TaskForge","category":"Tool","status":"in-progress","featured":false,"published":true,"summary":"Terminal project manager, a simplified Trello/Jira.","details":"Tasks, user-made columns, animated graphs, releases and builds.","tech":["Rust","TUI"],"links":[],"image":""},
  {"id":"critical-point","title":"Critical Point (game jam)","category":"Game","status":"completed","featured":false,"published":true,"summary":"Shift-management game about containing a black hole.","details":"Made for the 'critical point' jam theme.","tech":["Godot 4","GDScript"],"links":[],"image":""},
  {"id":"roguelike","title":"Roguelike arena fighter","category":"Game","status":"experimental","featured":false,"published":true,"summary":"2D roguelike arena fighting game.","details":"Combat, enemies, rounds and a boss fight.","tech":["Godot 4","GDScript"],"links":[],"image":""}
 ],
 "skills":[
  {"name":"Languages","items":["Rust","C","C++","Assembly","Java","Python","C#","GDScript"]},
  {"name":"Low-level","items":["Memory Management","Operating Systems","Compilers","Embedded Systems","Performance"]},
  {"name":"Tools","items":["Git","Linux","Docker","LLVM","Jira","Godot"]},
  {"name":"Hardware","items":["Arduino","Raspberry Pi","Electronics","Robotics","Mechatronics"]},
  {"name":"Concepts","items":["Data Structures","Algorithms","Concurrency","Systems Design","Security"]}
 ],
 "education":[{"title":"B.Sc. Software Engineering (confirm degree)","place":"[University name]","period":"[years]"}],
 "experience":[]
}
$json$::jsonb);

-- AFTER creating your admin user (Auth > Users), run this with YOUR email:
-- insert into public.admins (user_id) select id from auth.users where email = 'YOUR_EMAIL_HERE';

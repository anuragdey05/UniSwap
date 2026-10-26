-- Replace the sample institution and domain before inviting pilot users.
insert into public.institutions (name, slug, allowed_email_domain)
values ('Your College', 'your-college', 'college.edu')
on conflict (slug) do update set
  name = excluded.name,
  allowed_email_domain = excluded.allowed_email_domain;

insert into public.categories (name, slug, sort_order)
values
  ('Electronics', 'electronics', 10),
  ('Books and notes', 'books', 20),
  ('Cycles', 'cycles', 30),
  ('Room and hostel', 'room', 40),
  ('Sports', 'sports', 50),
  ('Fashion', 'fashion', 60),
  ('Other', 'other', 70)
on conflict (institution_id, slug) do update set
  name = excluded.name,
  sort_order = excluded.sort_order;


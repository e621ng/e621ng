begin;
alter table takedowns rename column ip_addr to creator_ip_addr;
alter table takedowns rename column user_id to creator_id;
alter table takedowns rename column approver to approver_id;
alter table takedowns add column post_ids text default '',
add column del_post_ids text default '',
add column post_count integer not null default 0;

ALTER TABLE public.takedowns ALTER COLUMN reason_hidden SET DEFAULT false;
ALTER TABLE public.takedowns ALTER COLUMN reason_hidden SET NOT NULL;
ALTER TABLE public.takedowns ALTER COLUMN status SET DEFAULT 'pending'::character varying;
ALTER TABLE public.takedowns ALTER COLUMN updated_at SET NOT NULL;
ALTER TABLE public.takedowns ALTER COLUMN vericode SET NOT NULL;

create index td_tmp on takedown_posts(takedown_id);
update takedowns set post_ids = (select string_agg(post_id::text, ' ') from takedown_posts _ where _.takedown_id = takedowns.id);
update takedowns set del_post_ids = (select string_agg(post_id::text, ' ') from takedown_posts _ where _.takedown_id = takedowns.id and status = 'deleted');
update takedowns set post_count = (select count(*) from takedown_posts _ where _.takedown_id = takedowns.id);
drop index td_tmp;
drop table takedown_posts;
commit;

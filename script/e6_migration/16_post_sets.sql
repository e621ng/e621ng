begin;
alter table set_maintainers rename to post_set_maintainers;

alter table post_sets rename column transfer_to_parent_on_delete to transfer_on_delete;
alter table post_sets rename column public to is_public;
alter table post_sets rename column user_id to creator_id;
alter table post_sets add column creator_ip_addr inet,
add column post_ids integer[] not null default '{}'::integer[];
ALTER TABLE post_sets ALTER COLUMN transfer_on_delete SET DEFAULT false;
ALTER TABLE post_sets ALTER COLUMN transfer_on_delete SET NOT NULL;

create index set_posts on set_entries(post_set_id);
update post_sets set post_ids = (select coalesce(array_agg(x.post_id), '{}'::integer[]) from (select _.post_id from set_entries _ where _.post_set_id = post_sets.id order by _.position) x);
UPDATE post_sets SET post_count = COALESCE(array_length(post_ids, 1), 0);
drop index set_posts;

drop table set_entries;
commit;

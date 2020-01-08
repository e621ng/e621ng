alter table set_maintainers rename to post_set_maintainers;

alter table post_sets rename column transfer_to_parent_on_delete to transfer_on_delete;
alter table post_sets rename column public to is_public;
alter table post_sets rename column user_id to creator_id;
alter table post_sets add column creator_ip_addr inet,
add column post_ids integer[] not null default '{}'::integer[];
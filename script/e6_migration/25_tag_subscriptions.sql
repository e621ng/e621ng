alter table tag_subscriptions rename column is_visible_on_profile to is_public;
alter table tag_subscriptions rename column cached_post_ids to post_ids;
alter table tag_subscriptions rename column user_id to creator_id;
alter table tag_subscriptions add column created_at timestamp,
add column updated_at timestamp,
add column last_accessed_at timestamp,
add column is_opted_in boolean not null default false;
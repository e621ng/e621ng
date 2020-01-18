-- post flags

alter table flagged_post_details rename to post_flags;
alter table post_flags add column updated_at timestamp;
alter table post_flags rename column user_id to creator_id;
alter table post_flags add column creator_ip_addr inet not null default '127.0.0.1';
alter table post_flags add column is_deletion boolean NOT NULL DEFAULT false;

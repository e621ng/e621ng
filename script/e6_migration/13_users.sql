alter table namechanges rename to user_name_change_requests;
alter table user_name_change_requests add column status varchar not null default 'pending',
add column rejection_reason varchar,
add column change_reason varchar;
alter table user_name_change_requests rename column oldname to original_name;
alter table user_name_change_requests rename column newname to desired_name;
alter table user_name_change_requests rename column mod to approver_id;
update user_name_change_requests set status = 'active';

alter table user_records rename to user_feedback;
alter table user_feedback add column category varchar not null default 'neutral',
add column updated_at timestamp,
add column creator_ip_addr inet not null default '127.0.0.1';
alter table user_feedback rename column reported_by to creator_id;
update user_feedback set category = 'positive' where score > 0;
update user_feedback set category = 'neutral' where score = 0;
update user_feedback set category = 'negitive' where score < 0;
alter table user_feedback drop column score;

alter table users drop column always_resize_images,
drop column show_samples,
drop column post_title,
drop column nojs_hide_explicit_thumbnails,
drop column sort_tags,
drop column hide_url_tags,
drop column classic_mode,
drop column ignore_theme_changes,
drop column show_thumb_tooltips;
alter table users rename column ip_addr to last_ip_addr;
alter table users rename column uploaded_tags to favorite_tags;
alter table users rename column last_forum_topic_read_at to last_forum_read_at;
alter table users rename column about to profile_about;
alter table users rename column rates to profile_artinfo;
alter table users add column blacklisted_tags text,
add column updated_at timestamp,
add column time_zone varchar not null default 'Eastern Time (US & Canada)',
add column unread_dmail_count int not null default 0,
add column bcrypt_password_hash varchar,
add column custom_style text,
add column bit_prefs bigint not null default 0;
update users set bit_prefs = bit_prefs | (1 << 0) where avatar_on = true;
update users set bit_prefs = bit_prefs | (1 << 1) where blacklist_avatars = true;
update users set bit_prefs = bit_prefs | (1 << 2) where blacklist_users = true;
update users set bit_prefs = bit_prefs | (1 << 3) where collapse_descriptions = true;
update users set bit_prefs = bit_prefs | (1 << 13) where enable_autocomplete = true;
update users set bit_prefs = bit_prefs | (1 << 8) where has_mail = true;
update users set bit_prefs = bit_prefs | (1 << 9) where receive_dmails = true;
update users set bit_prefs = bit_prefs | (1 << 4) where show_comments = false;
update users set bit_prefs = bit_prefs | (1 << 5) where show_hidden_comments = true;
update users set bit_prefs = bit_prefs | (1 << 6) where show_post_stats = true;
alter table users drop column avatar_on,
drop column blacklist_avatars,
drop column blacklist_users,
drop column collapse_descriptions,
drop column enable_autocomplete,
drop column has_mail,
drop column receive_dmails,
drop column show_comments,
drop column show_hidden_comments,
drop column show_post_stats;
alter table users add column default_image_size varchar not null default 'large',
add column email_verification_key varchar;
update users set default_image_size = 'large' where image_resize_mode = 2;
update users set default_image_size = 'original' where image_resize_mode = 0;
update users set default_image_size = 'fit' where image_resize_mode = 1;
alter table users drop column image_resize_mode;

update users set "level" = 20, email_verification_key = '1' WHERE "level" = 0;

create index blacklisted_by_user on user_blacklisted_tags(user_id);
update users set blacklisted_tags = (select array_to_string(array_agg(_.tags), E'\n') from user_blacklisted_tags _ where _.user_id = users.id);
drop index blacklisted_by_user;

alter table users alter column blacklisted_tags set default 'gore
scat
watersports
young -rating:s
loli
shota'::text;


alter table user_statuses rename column del_post_count to post_deleted_count;
alter table user_statuses rename column edit_count to post_update_count;
alter table user_statuses rename column public_set_count to set_count;
alter table user_statuses rename column wiki_count to wiki_edit_count;
alter table user_statuses rename column pool_count to pool_edit_count;
alter table user_statuses add column post_flag_count int not null default 0,
add column artist_edit_count int not null default 0,
add column created_at timestamp,
add column updated_at timestamp;
alter table user_statuses alter column user_id set not null;
alter table user_statuses drop column pos_user_records, drop column neg_user_records, drop column neutral_user_records;

create index flags_by_creator on post_flags(creator_id);
update user_statuses set post_flag_count = (select count(*) from post_flags _ where _.creator_id = user_statuses.user_id);
drop index flags_by_creator;

create index artist_update_by_updater on artist_versions(updater_id);
update user_statuses set artist_edit_count = (select count(*) from artist_versions _ where _.updater_id = user_statuses.user_id);
drop index artist_update_by_updater;

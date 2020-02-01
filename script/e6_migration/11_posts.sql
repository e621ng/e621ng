drop trigger trg_posts_tags_index_update on posts;

alter table posts rename column artist_tag_count to tag_count_artist;
alter table posts rename column cached_tags to tag_string;
alter table posts rename column character_tag_count to tag_count_character;
alter table posts rename column general_tag_count to tag_count_general;
alter table posts rename column copyright_tag_count to tag_count_copyright;
alter table posts rename column height to image_height;
alter table posts rename column width to image_width;
alter table posts rename column ip_addr to uploader_ip_addr;
alter table posts rename column user_id to uploader_id;
alter table posts rename column prevent_flagging to is_status_locked;
alter table posts rename column species_tag_count to tag_count_species;
alter table posts rename column tags_index to tag_index;
alter table posts rename column has_children to has_active_children;
alter table posts drop column is_warehoused;
alter table posts drop column sample_height;
alter table posts drop column sample_width;
alter table posts add column updated_at timestamp,
add column fav_string text not null default '',
add column pool_string text not null default '',
add column is_deleted boolean not null default false,
add column is_pending boolean not null default false,
add column is_flagged boolean not null default false,
add column pixiv_id int,
add column tag_count int not null default 0,
add column tag_count_meta int not null default 0,
add column tag_count_invalid int not null default 0,
add column tag_count_lore int not null default 0,
add column up_score int not null default 0,
add column down_score int not null default 0,
add column bit_flags bigint not null default 0,
add column has_children boolean not null default false,
add column last_comment_bumped_at timestamp,
add column bg_color character varying(8);
alter table posts drop column view_count;

create sequence posts_change_seq_seq;
select setval('posts_change_seq_seq', MAX(change_seq) + 1) from posts;
ALTER TABLE posts ALTER COLUMN change_seq TYPE bigint;
ALTER TABLE posts ALTER COLUMN change_seq SET DEFAULT nextval('posts_change_seq_seq'::regclass);
ALTER TABLE posts ALTER COLUMN change_seq SET NOT NULL;

update posts set last_comment_bumped_at = last_commented_at;
update posts set is_pending = true where status = 'pending';
update posts set is_flagged = true where status = 'flagged';
update posts set is_deleted = true where status = 'deleted';
update posts set tag_count = tag_count_general + tag_count_artist + tag_count_character + tag_count_copyright + tag_count_species;
update posts set bit_flags = (bit_flags | 4) where hide_anon = true;
update posts set bit_flags = (bit_flags | 8) where hide_google = true;

alter table posts drop column hide_anon;
alter table posts drop column hide_google;
alter table posts drop column status;

alter table post_tag_histories rename to post_versions;
ALTER TABLE public.post_versions DROP COLUMN IF EXISTS revertuser;
ALTER TABLE public.post_versions ALTER COLUMN id TYPE bigint;
alter table post_versions rename column user_id to updater_id;
alter table post_versions rename column ip_addr to updater_ip_addr;
alter table post_versions rename column created_at to updated_at;
alter table post_versions add column added_tags text[] not null default '{}'::text[],
add column removed_tags text[] not null default '{}'::text[],
add column added_locked_tags text[] not null default '{}'::text[],
add column removed_locked_tags text[] not null default '{}'::text[],
add column rating_changed boolean not null default false,
add column parent_changed boolean not null default false,
add column source_changed boolean not null default false,
add column description_changed boolean not null default false,
add column version integer not null default 1;

create temp table post_version_versions as select id, row_number() OVER (PARTITION BY post_id ORDER BY id) as version FROM post_versions;
update post_versions pv set version = pvv.version from post_version_versions pvv WHERE pv.id = pvv.id;
drop table post_version_versions;

alter table post_votes rename column ip_addr to user_ip_addr;


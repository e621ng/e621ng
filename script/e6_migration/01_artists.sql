-- Artists

alter table artists drop column version;
alter table artists drop column updater_id;
alter table artists rename column other_names_array to other_names;
alter table artists rename column user_id to linked_user_id;
alter table artists add column created_at timestamp not null default now();
alter table artists add column is_banned boolean not null default false;
alter table artists add column creator_id int;
update artists set creator_id = 1;
alter table artists alter column creator_id set not null;
alter table artists alter column other_names set default '{}'::text[];
update artists set other_names = default where other_names is null;
alter table artists alter column other_names set not null;
alter table artists alter column group_name set default '';
update artists set group_name = default where group_name is null;
alter table artists alter column group_name set not null;

alter table artist_urls add column created_at timestamp not null default now();
alter table artist_urls add column updated_at timestamp not null default now();
alter table artist_urls add column is_active boolean not null default true;

alter table artist_versions drop column version;
alter table artist_versions rename column other_names_array to other_names;
alter table artist_versions add column updater_ip_addr inet not null default '127.0.0.1';
alter table artist_versions add column is_banned boolean not null default false;
alter table artist_versions add column notes_changed boolean default false;
alter table artist_versions add column urls text[] not null default '{}'::text[];
update artist_versions set urls = string_to_array(cached_urls, ' ');
alter table artist_versions drop column cached_urls;
alter table artist_versions alter column group_name set default '';
update artist_versions set group_name = default where group_name is null;
alter table artist_versions alter column group_name set not null;
delete from artist_versions where artist_id is null;
alter table artist_versions alter column artist_id set not null;
alter table artist_versions alter column updater_id set not null;
alter table artist_versions alter column "name" set not null;
alter table artist_versions alter column other_names set default '{}'::text[];
update artist_versions set other_names = default where other_names is null;
alter table artist_versions alter column other_names set not null;

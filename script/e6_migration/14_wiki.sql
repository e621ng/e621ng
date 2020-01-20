alter table wiki_pages rename column user_id to creator_id;
alter table wiki_pages rename column ip_addr to creator_ip_addr;
alter table wiki_pages drop column creator_ip_addr; -- TODO: Keep this?
alter table wiki_pages rename column text_search_index to body_index;
alter table wiki_pages drop column version;
alter table wiki_pages add column updater_id int,
add column is_deleted boolean not null default false,
add column other_names text[] not null default '{}'::text[];

alter table wiki_page_versions rename column user_id to updater_id;
alter table wiki_page_versions rename column ip_addr to updater_ip_addr;
alter table wiki_page_versions drop column version;
alter table wiki_page_versions drop column text_search_index;
alter table wiki_page_versions add column other_names text[] not null default '{}'::text[],
add column is_deleted boolean not null default false,
add column reason character varying(1000);

delete from wiki_pages a using wiki_pages b where a.id < b.id and a.title = b.title;

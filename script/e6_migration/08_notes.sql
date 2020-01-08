-- notes

alter table notes rename column user_id to creator_id;
alter table notes rename column ip_addr to creator_ip_addr;
alter table notes rename column text_search_index to body_index;

alter table note_versions rename column ip_addr to updater_ip_addr;
alter table note_versions rename column user_id to updater_id;
alter table note_versions drop column text_search_index;
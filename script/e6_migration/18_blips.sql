drop trigger trg_blip_search_update on blips;

alter table blips rename column text_search_index to body_index;
alter table blips rename column response to response_to;
alter table blips rename column user_id to creator_id;
alter table blips rename column ip_addr to creator_ip_addr;
alter table blips add column is_hidden boolean default false;
update blips set is_hidden = true where status = 'hidden';
alter table blips drop column status;
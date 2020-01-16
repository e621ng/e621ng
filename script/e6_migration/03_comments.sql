-- Comments

drop trigger trg_comment_search_update on comments;

alter table comment_votes rename column ip_addr to user_ip_addr;
update comment_votes set score = 0 where score is null;
alter table comment_votes alter column score set not null;

alter table comments rename column text_search_index to body_index;
alter table comments rename column user_id to creator_id;
alter table comments rename column ip_addr to creator_ip_addr;
alter table comments add column updated_at timestamp not null default now();
alter table comments add column updater_id integer;
alter table comments add column updater_ip_addr inet;
alter table comments add column do_not_bump_post boolean not null default false;
alter table comments add column is_hidden boolean not null default false;
alter table comments add column is_sticky boolean not null default false;
update comments set is_hidden = true where status = 'hidden';
alter table comments drop column status;
update comments set creator_id = 1 where creator_id is null;
alter table comments alter column creator_id set not null;

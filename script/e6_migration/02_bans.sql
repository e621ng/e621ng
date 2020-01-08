-- Bans
alter table bans drop column old_level;
alter table bans rename column banned_by to banner_id;
alter table bans add column created_at timestamp not null default now();
alter table bans add column updated_at timestamp not null default now();

alter table banned_ips rename to ip_bans;
alter table ip_bans drop column id;
alter table ip_bans add column id serial primary key;
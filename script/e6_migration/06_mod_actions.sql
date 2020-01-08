-- mod actions
-- Need to convert values using ruby because they are encoded in ruby objects

alter table mod_actions rename column values to values_old;
alter table mod_actions rename column user_id to creator_id;
alter table mod_actions add column values json;
alter table mod_actions add column category integer;
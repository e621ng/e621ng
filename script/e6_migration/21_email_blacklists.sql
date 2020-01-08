alter table email_blacklists rename column user_id to creator_id;
alter table email_blacklists alter column id type bigint;
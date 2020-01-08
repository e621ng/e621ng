alter table password_resets rename to user_password_reset_nonces;
alter table user_password_reset_nonces add column updated_at timestamp;
delete from user_password_reset_nonces where user_id is null;
alter table user_password_reset_nonces alter column user_id set not null;
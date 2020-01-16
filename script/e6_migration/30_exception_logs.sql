truncate table exception_logs;
alter table exception_logs alter column code type uuid using code::uuid;
alter table exception_logs rename column extra to extra_params;
alter table exception_logs add column ip_addr inet not null;
ALTER TABLE exception_logs ALTER COLUMN message SET NOT NULL;
ALTER TABLE exception_logs ALTER COLUMN trace SET NOT NULL;
alter table exception_logs add column user_id integer;

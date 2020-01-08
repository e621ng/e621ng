alter table upload_whitelists alter column hidden set not null;
alter table upload_whitelists add column allowed boolean not null default true;
alter table upload_whitelists add column reason varchar;

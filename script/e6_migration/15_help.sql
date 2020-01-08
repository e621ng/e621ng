alter table help rename to help_pages;
alter table help_pages add column created_at timestamp not null default now(),
add column updated_at timestamp not null default now();
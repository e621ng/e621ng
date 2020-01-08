-- DMails

alter table dmails rename to dmails_orig;
alter sequence dmails_id_seq rename to dmails_old_id_seq;

create table dmails (
  id bigserial not null,
  owner_id int not null,
  creator_ip_addr inet not null,
  from_id int not null,
  to_id int not null,
  title text not null,
  body text not null,
  message_index tsvector not null,
  is_read boolean not null default false,
  is_deleted boolean not null default false,
  is_spam boolean not null default false,
  created_at timestamp,
  updated_at timestamp
);

create trigger trigger_dmails_on_update BEFORE INSERT OR UPDATE ON dmails FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('message_index', 'pg_catalog.english', 'title', 'body');
insert into dmails (owner_id, from_id, to_id, title, body, is_read, is_deleted, created_at, updated_at, creator_ip_addr) select dmails_orig.from_id, dmails_orig.from_id, dmails_orig.to_id, dmails_orig.title, dmails_orig.body, dmails_orig.has_seen, from_hidden, dmails_orig.created_at, dmails_orig.created_at, '127.0.0.1' from dmails_orig;
insert into dmails (owner_id, from_id, to_id, title, body, is_read, is_deleted, created_at, updated_at, creator_ip_addr) select dmails_orig.to_id, dmails_orig.from_id, dmails_orig.to_id, dmails_orig.title, dmails_orig.body, dmails_orig.has_seen, to_hidden, dmails_orig.created_at, dmails_orig.created_at, '127.0.0.1' from dmails_orig;
drop table dmails_orig;

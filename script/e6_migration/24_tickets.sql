alter table tickets rename column user_id to creator_id;
alter table tickets rename column ip_addr to creator_ip_addr;
alter table tickets rename column admin_id to handler_id;
alter table tickets rename column claim_id to claimant_id;
alter table tickets add column report_reason varchar;
alter table tickets drop column oldname, drop column disp_type;


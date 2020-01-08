-- Remove all duplicate ip bans because they are now uniquely indexed
delete from ip_bans a using ip_bans b where a.id < b.id and a.ip_addr = b.ip_addr;
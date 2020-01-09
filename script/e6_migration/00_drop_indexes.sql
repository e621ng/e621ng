-- SELECT  'DROP INDEX '||                  
--     c.oid::regclass ||';'
-- FROM
--     pg_catalog.pg_class c
--     JOIN pg_catalog.pg_index i ON (
--         c.oid = i.indexrelid )
--     JOIN pg_class t ON (
--         i.indrelid = t.oid )
--     JOIN pg_namespace n ON (
--         c.relnamespace = n.oid )
-- WHERE
--     c.relkind = 'i'
--     AND NOT EXISTS (
--         SELECT
--             1
--         FROM
--             pg_catalog.pg_constraint
--         WHERE
--             conindid = c.oid
--             AND contype != 'f'
--         LIMIT 1 )
--     AND n.nspname = 'public' -- include your schemaname

--     AND t.relkind IN (
--         'r' :: "char",
--         'm' :: "char",
--         'p' :: "char")
--     AND EXISTS (
--         SELECT
--             1
--         FROM
--             pg_catalog.pg_depend d
--         WHERE
--             d.objid = t.oid
--             AND d.classid = 'pg_catalog.pg_class' ::REGCLASS:: OID
--             AND d.objsubid = 0
--             AND d.deptype = 'e'
--         LIMIT 1 );


SELECT  'DROP INDEX '||                  
    c.oid::regclass ||';'
FROM
    pg_catalog.pg_class c
    JOIN pg_catalog.pg_index i ON (
        c.oid = i.indexrelid )
    JOIN pg_class t ON (
        i.indrelid = t.oid )
    JOIN pg_namespace n ON (
        c.relnamespace = n.oid )
WHERE
    c.relkind = 'i'
    AND n.nspname = 'public' -- include your schemaname

    AND t.relkind IN (
        'r' :: "char",
        'm' :: "char",
        'p' :: "char");

SELECT 'ALTER TABLE "'||nspname||'"."'||relname||'" DROP CONSTRAINT "'||conname||'";'
 FROM pg_constraint 
 INNER JOIN pg_class ON conrelid=pg_class.oid 
 INNER JOIN pg_namespace ON pg_namespace.oid=pg_class.relnamespace 
 ORDER BY CASE WHEN contype='f' THEN 0 ELSE 1 END,contype,nspname,relname,conname;
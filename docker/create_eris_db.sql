-- Runs via /docker-entrypoint-initdb.d on fresh volumes only.
-- Existing volumes: docker compose exec postgres createdb -U e621 eris
CREATE DATABASE eris;

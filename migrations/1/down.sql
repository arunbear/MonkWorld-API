-- Drop triggers first to avoid dependency issues
DROP TRIGGER IF EXISTS update_node_modtime ON node;
DROP TRIGGER IF EXISTS update_author_modtime ON monk;

-- Drop the update_modified_column function
DROP FUNCTION IF EXISTS update_modified_column() CASCADE;

-- Drop tables in reverse order of creation to handle foreign key constraints
DROP TABLE IF EXISTS note CASCADE;
DROP TABLE IF EXISTS node CASCADE;
DROP TABLE IF EXISTS node_type CASCADE;
DROP TABLE IF EXISTS monk CASCADE;

-- Drop the ltree extension
DROP EXTENSION IF EXISTS ltree;

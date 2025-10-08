-- SQL Schema for storing Perl questions and discussions

CREATE TABLE node_type (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(50) NOT NULL UNIQUE,
    description TEXT        NOT NULL
);

CREATE TABLE author (
    id           SERIAL PRIMARY KEY,
    username     VARCHAR(100) NOT NULL UNIQUE,
    is_anonymous BOOLEAN   DEFAULT FALSE,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for storing user posts
CREATE TABLE node (
    id           BIGSERIAL PRIMARY KEY,
    node_type_id INTEGER REFERENCES node_type (id),
    author_id    INTEGER REFERENCES author (id),
    title        VARCHAR(255) NOT NULL,
    content      TEXT         NOT NULL,
    reputation   INTEGER      NOT NULL DEFAULT 0,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for better query performance
CREATE INDEX idx_node_created ON node(created_at);
CREATE INDEX idx_node_author ON node(author_id);
CREATE INDEX idx_node_type ON node(node_type_id);

-- Add node types
INSERT INTO node_type (id, name, description)
VALUES (11, 'note', 'A comment on a node');

INSERT INTO node_type (id, name, description)
VALUES (115, 'perlquestion', 'A question about Perl programming');

-- Insert the anonymous user
INSERT INTO author (id, username, created_at, updated_at)
VALUES (961, 'Anonymous Monk', NOW(), NOW());

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to automatically update timestamps
CREATE TRIGGER update_node_modtime
BEFORE UPDATE ON node
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_author_modtime
BEFORE UPDATE ON author
FOR EACH ROW EXECUTE FUNCTION update_modified_column();


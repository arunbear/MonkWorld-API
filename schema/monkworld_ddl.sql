-- SQL Schema for storing Perl questions and discussions

-- Table for storing node type
CREATE TABLE node_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

-- Table for storing user/author
CREATE TABLE author (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    is_anonymous BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for storing node (question, answer, etc.)
CREATE TABLE node (
    id BIGINT PRIMARY KEY,
    title VARCHAR(255),
    node_type_id INTEGER REFERENCES node_type(id),
    author_id INTEGER REFERENCES author(id),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    content TEXT,
    reputation INTEGER DEFAULT 0,
    CONSTRAINT fk_node_type FOREIGN KEY(node_type_id) REFERENCES node_type(id),
    CONSTRAINT fk_author FOREIGN KEY(author_id) REFERENCES author(id)
);

-- Indexes for better query performance
CREATE INDEX idx_node_created ON node(created_at);
CREATE INDEX idx_node_author ON node(author_id);
CREATE INDEX idx_node_type ON node(node_type_id);

-- Add node types
INSERT INTO node_type (id, name, description)
VALUES (11, 'note', 'A comment on a node');

INSERT INTO node_type (id, name, description)
VALUES (115, 'perlquestion', 'A question about Perl programming language');

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


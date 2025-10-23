BEGIN TRANSACTION;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- auth section for users

CREATE TABLE users
(
    id                  UUID PRIMARY KEY   DEFAULT gen_random_uuid(),
    email               CITEXT    NOT NULL UNIQUE,
    email_confirmed_at  TIMESTAMPTZ NULL,
    display_name        CITEXT    NULL,
    admin_level         INT       NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at          TIMESTAMPTZ NULL,
    current_password_id INT       NULL
);

CREATE UNIQUE INDEX unique_display_name ON users (display_name) WHERE display_name IS NOT NULL;

ALTER TABLE users
    ADD CONSTRAINT valid_email CHECK (
        email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
        );

CREATE TABLE user_components (
    user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    component_name  TEXT        NOT NULL,
    data            JSONB       NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (user_id, component_name)
);

CREATE TABLE user_events (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    topic TEXT NOT NULL,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    PRIMARY KEY (user_id, event_id)
);

CREATE TABLE passwords
(
    id         SERIAL PRIMARY KEY,
    user_id    UUID      NOT NULL,
    password   TEXT      NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

ALTER TABLE users
    ADD CONSTRAINT fk_current_password
        FOREIGN KEY (current_password_id) REFERENCES passwords (id) ON DELETE SET NULL;

CREATE VIEW user_passwords AS
SELECT u.*,
       p.id         AS password_id,
       p.password,
       p.created_at AS password_created_at
FROM users u
         LEFT JOIN passwords p ON u.current_password_id = p.id;

CREATE TABLE loginrecords
(
    id         BIGSERIAL PRIMARY KEY,
    user_id    UUID      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address INET      NOT NULL,
    user_agent TEXT      NOT NULL,
    success    BOOLEAN   NOT NULL
);

CREATE VIEW loginrecords_with_user AS
SELECT l.id,
       l.user_id,
       l.created_at,
       l.ip_address,
       l.user_agent,
       l.success,
       u.email,
       u.display_name
FROM loginrecords l
         JOIN users u ON l.user_id = u.id;

-- characters section
CREATE TABLE characters
(
    id             UUID PRIMARY KEY   DEFAULT gen_random_uuid(),
    user_id        UUID      NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    name           CITEXT    NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at     TIMESTAMPTZ NULL
);

CREATE UNIQUE INDEX unique_character_name ON characters (name) WHERE deleted_at IS NULL;

CREATE TABLE character_components (
    character_id    UUID        NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    component_name  TEXT        NOT NULL,
    data            JSONB       NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (character_id, component_name)
);

CREATE TABLE character_sessions (
    character_id UUID NOT NULL PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    activity_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE character_events (
    character_id UUID NOT NULL REFERENCES character_sessions(character_id) ON DELETE CASCADE,
    event_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    topic TEXT NOT NULL,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    PRIMARY KEY(character_id, event_id)
);

COMMIT;
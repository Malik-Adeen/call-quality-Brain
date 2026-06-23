CREATE EXTENSION IF NOT EXISTS "pgcrypto";


CREATE TABLE IF NOT EXISTS users (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name          TEXT         NOT NULL,
    email         TEXT         UNIQUE NOT NULL,
    password_hash TEXT         NOT NULL,
    role          TEXT         NOT NULL CHECK (role IN ('ADMIN', 'SUPERVISOR', 'VIEWER')),
    created_at    TIMESTAMPTZ  DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS agents (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT        NOT NULL,
    team       TEXT        NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS calls (
    id                   UUID         PRIMARY KEY,
    agent_id             UUID         NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    minio_audio_path     TEXT,
    transcript_redacted  TEXT,
    duration             INTEGER,
    score                NUMERIC(4,2) CHECK (score >= 0 AND score <= 10),
    resolved             BOOLEAN      DEFAULT FALSE,
    sentiment_start      NUMERIC(6,4),
    sentiment_end        NUMERIC(6,4),
    pii_redacted         BOOLEAN      DEFAULT FALSE,
    status               TEXT         DEFAULT 'pending'
                                      CHECK (status IN ('pending', 'processing', 'complete', 'failed')),
    issue_category       TEXT,
    coaching_summary     TEXT,
    created_at           TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_calls_agent_id    ON calls(agent_id);
CREATE INDEX IF NOT EXISTS idx_calls_created_at  ON calls(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_calls_score       ON calls(score);
CREATE INDEX IF NOT EXISTS idx_calls_resolved    ON calls(resolved);
CREATE INDEX IF NOT EXISTS idx_calls_status      ON calls(status);


CREATE TABLE IF NOT EXISTS call_metrics (
    id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    call_id             UUID         NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    politeness_score    NUMERIC(5,4),
    sentiment_delta     NUMERIC(6,4),
    resolution_score    NUMERIC(5,4),
    talk_balance_score  NUMERIC(5,4),
    clarity_score       NUMERIC(5,4)
);

CREATE INDEX IF NOT EXISTS idx_call_metrics_call_id ON call_metrics(call_id);


CREATE TABLE IF NOT EXISTS sentiment_timeline (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    call_id           UUID         NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    timestamp_seconds INTEGER      NOT NULL,
    sentiment_value   NUMERIC(6,4) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sentiment_timeline_call_id ON sentiment_timeline(call_id);


INSERT INTO users (name, email, password_hash, role) VALUES
    ('Demo Admin',      'admin@callquality.demo',      '$2b$12$placeholder_admin_hash',      'ADMIN'),
    ('Demo Supervisor', 'supervisor@callquality.demo', '$2b$12$placeholder_supervisor_hash', 'SUPERVISOR'),
    ('Demo Viewer',     'viewer@callquality.demo',     '$2b$12$placeholder_viewer_hash',     'VIEWER')
ON CONFLICT (email) DO NOTHING;
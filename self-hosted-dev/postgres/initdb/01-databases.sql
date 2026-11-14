-- ==============================================================================
-- IAOP Self-Hosted DEV PostgreSQL Initialization Script
-- Databases & Role Separation for Microservices Ecosystem
-- ==============================================================================

-- 1. Keycloak Identity Database
SELECT 'CREATE DATABASE iaop_keycloak'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'iaop_keycloak')\gexec

-- 2. Domain Services Databases
SELECT 'CREATE DATABASE iaop_agent'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'iaop_agent')\gexec

SELECT 'CREATE DATABASE iaop_agency'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'iaop_agency')\gexec

SELECT 'CREATE DATABASE iaop_agent_bff'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'iaop_agent_bff')\gexec

SELECT 'CREATE DATABASE iaop_integration'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'iaop_integration')\gexec

-- 3. Workflow Engine Database (Flowable OSS 7)
SELECT 'CREATE DATABASE iaop_workflow'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'iaop_workflow')\gexec

-- Grant extensions
\c iaop_agent
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

\c iaop_agency
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

\c iaop_agent_bff
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

\c iaop_integration
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

\c iaop_workflow
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

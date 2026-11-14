-- IAOP DEV databases, roles and grants.
-- Each domain service gets its own database AND its own role — no shared
-- superuser credentials at runtime. Runs once on first container init.

CREATE USER agent_svc    WITH PASSWORD :'agent_pw';
CREATE USER agency_svc   WITH PASSWORD :'agency_pw';
CREATE USER elig_svc     WITH PASSWORD :'elig_pw';
CREATE USER bff_svc      WITH PASSWORD :'bff_pw';

CREATE DATABASE agent_db     OWNER agent_svc;
CREATE DATABASE agency_db    OWNER agency_svc;
CREATE DATABASE eligibility_db OWNER elig_svc;
CREATE DATABASE bff_db       OWNER bff_svc;

-- Run this AFTER 001_initial.sql to grant API access to the ak_ tables
-- Without this, Supabase REST API can't access the tables

-- Grant usage on public schema
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- ak_users
GRANT SELECT ON ak_users TO anon, authenticated;
GRANT INSERT, UPDATE ON ak_users TO authenticated;
GRANT ALL ON ak_users TO service_role;

-- ak_audits
GRANT SELECT ON ak_audits TO anon, authenticated;
GRANT INSERT, UPDATE ON ak_audits TO service_role;
GRANT INSERT ON ak_audits TO authenticated;

-- ak_audit_issues
GRANT SELECT ON ak_audit_issues TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON ak_audit_issues TO service_role;

-- ak_payments
GRANT SELECT ON ak_payments TO authenticated;
GRANT INSERT, UPDATE ON ak_payments TO service_role;

-- ak_audit_cache
GRANT ALL ON ak_audit_cache TO service_role;
GRANT SELECT ON ak_audit_cache TO anon, authenticated;

-- Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';

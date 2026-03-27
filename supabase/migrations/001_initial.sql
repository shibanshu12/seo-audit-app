-- AuditKaro tables — all prefixed with ak_ to avoid collision with ai-digest tables
-- Run this in your Supabase SQL editor or via API

-- ============================================
-- USERS
-- ============================================
CREATE TABLE IF NOT EXISTS ak_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  avatar_url TEXT,
  plan TEXT DEFAULT 'free' CHECK (plan IN ('free', 'standard', 'pro', 'agency', 'enterprise')),
  credits INTEGER DEFAULT 3,
  stripe_customer_id TEXT,
  razorpay_customer_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- AUDITS
-- ============================================
CREATE TABLE IF NOT EXISTS ak_audits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES ak_users(id) ON DELETE SET NULL,
  url TEXT NOT NULL,
  url_hash TEXT NOT NULL,
  status TEXT DEFAULT 'queued' CHECK (status IN ('queued', 'crawling', 'measuring', 'comparing', 'judging', 'synthesizing', 'complete', 'partial', 'failed')),
  tier TEXT DEFAULT 'free' CHECK (tier IN ('free', 'standard', 'premium')),
  
  -- Scores
  overall_score INTEGER,
  grade TEXT,
  scores JSONB DEFAULT '{}',
  -- { technical: 78, onpage: 71, content: 54, ux: 68, conversion: 58, aiReadiness: 41, aioSimulation: 39 }

  -- Detailed findings per dimension
  dimensions JSONB DEFAULT '{}',
  -- Each dimension: { score, grade, summary, details: [{ check, score, maxScore, status, evidence, fix }] }

  -- Top prioritized fixes
  top_fixes JSONB DEFAULT '[]',
  -- [{ title, description, estimatedImpact, effort, owner, estimatedMinutes, pageUrl }]

  -- Competitor data
  competitors JSONB DEFAULT '[]',
  -- [{ url, overall, dimensions: { technical: N, ... } }]

  -- AIO simulation result
  aio_simulation JSONB DEFAULT '{}',
  -- { cited, keyword, overviewText, citedSource, targetPageReason, minimumEditToWin, fanOutCoverage, formatMatch, citableUnits }

  -- Narratives (LLM-generated)
  conversion_narrative TEXT,
  persona_narrative TEXT,
  strategic_synthesis TEXT,

  -- Raw signal sheets (for re-scoring without re-crawling)
  signal_sheets JSONB DEFAULT '{}',

  -- Screenshots
  screenshots JSONB DEFAULT '{}',
  -- { desktop: url, mobile: url, video: url }

  -- Metadata
  metadata JSONB DEFAULT '{}',
  -- { pagesCrawled, timeTakenMs, llmCalls, llmCostUsd, completedAt, failedPhases: [] }

  -- Payment reference
  payment_id TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '90 days'
);

-- ============================================
-- AUDIT ISSUES (denormalized for fast filtering/export)
-- ============================================
CREATE TABLE IF NOT EXISTS ak_audit_issues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id UUID REFERENCES ak_audits(id) ON DELETE CASCADE,
  
  category TEXT NOT NULL CHECK (category IN ('technical', 'onpage', 'content', 'ux', 'conversion', 'ai_readiness', 'aio')),
  severity TEXT NOT NULL CHECK (severity IN ('critical', 'high', 'medium', 'low')),
  
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  page_url TEXT,
  evidence TEXT,
  fix TEXT NOT NULL,
  
  impact TEXT CHECK (impact IN ('high', 'medium', 'low')),
  effort TEXT CHECK (effort IN ('easy', 'medium', 'hard')),
  owner TEXT CHECK (owner IN ('dev', 'content', 'marketing')),
  estimated_minutes INTEGER,
  
  -- For screenshot annotation overlay
  element_coords JSONB,
  -- { x, y, width, height, page: 'desktop' | 'mobile' }

  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- PAYMENTS
-- ============================================
CREATE TABLE IF NOT EXISTS ak_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES ak_users(id) ON DELETE SET NULL,
  audit_id UUID REFERENCES ak_audits(id) ON DELETE SET NULL,
  
  razorpay_payment_id TEXT,
  razorpay_order_id TEXT NOT NULL,
  razorpay_signature TEXT,
  
  amount INTEGER NOT NULL, -- in paise (900 = Rs 9)
  currency TEXT DEFAULT 'INR',
  status TEXT DEFAULT 'created' CHECK (status IN ('created', 'authorized', 'captured', 'refunded', 'failed')),
  
  tier TEXT NOT NULL CHECK (tier IN ('standard', 'premium', 'bulk_10')),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- AUDIT CACHE (dedup same URL within 48 hours)
-- ============================================
CREATE TABLE IF NOT EXISTS ak_audit_cache (
  url_hash TEXT PRIMARY KEY,
  audit_id UUID REFERENCES ak_audits(id) ON DELETE CASCADE,
  tier TEXT NOT NULL,
  cached_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '48 hours'
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_ak_audits_user ON ak_audits(user_id);
CREATE INDEX IF NOT EXISTS idx_ak_audits_url_hash ON ak_audits(url_hash);
CREATE INDEX IF NOT EXISTS idx_ak_audits_status ON ak_audits(status);
CREATE INDEX IF NOT EXISTS idx_ak_audits_created ON ak_audits(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ak_issues_audit ON ak_audit_issues(audit_id);
CREATE INDEX IF NOT EXISTS idx_ak_issues_severity ON ak_audit_issues(severity);
CREATE INDEX IF NOT EXISTS idx_ak_issues_category ON ak_audit_issues(category);
CREATE INDEX IF NOT EXISTS idx_ak_payments_user ON ak_payments(user_id);
CREATE INDEX IF NOT EXISTS idx_ak_payments_audit ON ak_payments(audit_id);
CREATE INDEX IF NOT EXISTS idx_ak_payments_status ON ak_payments(status);
CREATE INDEX IF NOT EXISTS idx_ak_cache_expires ON ak_audit_cache(expires_at);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

-- Enable RLS on all tables
ALTER TABLE ak_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE ak_audits ENABLE ROW LEVEL SECURITY;
ALTER TABLE ak_audit_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE ak_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE ak_audit_cache ENABLE ROW LEVEL SECURITY;

-- Users: can read/update own row
CREATE POLICY ak_users_select ON ak_users FOR SELECT USING (auth.uid() = id);
CREATE POLICY ak_users_update ON ak_users FOR UPDATE USING (auth.uid() = id);

-- Audits: can read own audits, service role can do everything
CREATE POLICY ak_audits_select ON ak_audits FOR SELECT USING (
  user_id = auth.uid() OR user_id IS NULL  -- NULL user_id = free anonymous audits
);
CREATE POLICY ak_audits_insert ON ak_audits FOR INSERT WITH CHECK (true); -- worker inserts via service role
CREATE POLICY ak_audits_update ON ak_audits FOR UPDATE USING (true); -- worker updates via service role

-- Issues: readable if parent audit is readable
CREATE POLICY ak_issues_select ON ak_audit_issues FOR SELECT USING (
  EXISTS (SELECT 1 FROM ak_audits WHERE ak_audits.id = audit_id AND (ak_audits.user_id = auth.uid() OR ak_audits.user_id IS NULL))
);
CREATE POLICY ak_issues_insert ON ak_audit_issues FOR INSERT WITH CHECK (true);

-- Payments: can read own payments
CREATE POLICY ak_payments_select ON ak_payments FOR SELECT USING (user_id = auth.uid());
CREATE POLICY ak_payments_insert ON ak_payments FOR INSERT WITH CHECK (true);
CREATE POLICY ak_payments_update ON ak_payments FOR UPDATE USING (true);

-- Cache: service role only (no direct user access needed)
CREATE POLICY ak_cache_all ON ak_audit_cache FOR ALL USING (true);

-- ============================================
-- HELPER FUNCTION: auto-update updated_at
-- ============================================
CREATE OR REPLACE FUNCTION ak_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ak_users_updated_at BEFORE UPDATE ON ak_users
  FOR EACH ROW EXECUTE FUNCTION ak_update_updated_at();

CREATE TRIGGER ak_payments_updated_at BEFORE UPDATE ON ak_payments
  FOR EACH ROW EXECUTE FUNCTION ak_update_updated_at();

-- ============================================
-- HELPER FUNCTION: clean expired cache
-- ============================================
CREATE OR REPLACE FUNCTION ak_clean_expired_cache()
RETURNS void AS $$
BEGIN
  DELETE FROM ak_audit_cache WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

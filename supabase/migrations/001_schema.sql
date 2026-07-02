-- ============================================================
-- ORACLE Fee Management System — Database Schema
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. PROFILES (extends Supabase auth.users)
-- ============================================================
CREATE TABLE public.profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name       VARCHAR(255) NOT NULL,
  email           VARCHAR(255) UNIQUE NOT NULL,
  phone           VARCHAR(20),
  role            VARCHAR(20) NOT NULL DEFAULT 'parent' CHECK (role IN ('admin', 'organization', 'parent', 'student')),
  organization_id UUID REFERENCES public.profiles(id), -- Self-referencing link for members to their org
  avatar_url      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 2. STUDENTS
-- ============================================================
CREATE TABLE public.students (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id   UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  roll_number  VARCHAR(50) UNIQUE NOT NULL,
  grade        VARCHAR(20) NOT NULL,
  section      VARCHAR(10),
  parent_id    UUID REFERENCES public.profiles(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 3. FEE STRUCTURES (Dynamic fee engine)
-- ============================================================
CREATE TABLE public.fee_structures (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title           VARCHAR(255) NOT NULL,
  description     TEXT,
  base_amount     NUMERIC(12, 2) NOT NULL,
  category        VARCHAR(50) NOT NULL CHECK (category IN ('tuition', 'transport', 'hostel', 'lab', 'library', 'sports', 'other')),
  academic_year   VARCHAR(20) NOT NULL,
  applicable_grades TEXT[], -- NULL = all grades
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 4. STUDENT ALLOCATIONS (per-student fee mapping)
-- ============================================================
CREATE TABLE public.student_allocations (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id        UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  fee_structure_id  UUID NOT NULL REFERENCES public.fee_structures(id) ON DELETE RESTRICT,
  due_date          TIMESTAMPTZ NOT NULL,
  base_amount       NUMERIC(12, 2) NOT NULL, -- snapshot at allocation time
  status            VARCHAR(20) NOT NULL DEFAULT 'UNPAID'
                    CHECK (status IN ('UNPAID', 'PARTIALLY_PAID', 'PAID', 'WAIVED')),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(student_id, fee_structure_id)
);

-- ============================================================
-- 5. ADJUSTMENTS (Waivers & Penalties — auditable log)
-- ============================================================
CREATE TABLE public.adjustments (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  allocation_id  UUID NOT NULL REFERENCES public.student_allocations(id) ON DELETE CASCADE,
  type           VARCHAR(10) NOT NULL CHECK (type IN ('WAIVER', 'PENALTY')),
  amount         NUMERIC(12, 2) NOT NULL,
  reason         TEXT NOT NULL,
  applied_by     UUID REFERENCES public.profiles(id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 6. TRANSACTIONS (Omnichannel ledger — UPI, CASH, CHEQUE)
-- ============================================================
CREATE TABLE public.transactions (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  allocation_id        UUID NOT NULL REFERENCES public.student_allocations(id) ON DELETE RESTRICT,
  amount_paid          NUMERIC(12, 2) NOT NULL,
  payment_method       VARCHAR(10) NOT NULL CHECK (payment_method IN ('UPI', 'CASH', 'CHEQUE')),
  payment_status       VARCHAR(10) NOT NULL DEFAULT 'PENDING'
                       CHECK (payment_status IN ('PENDING', 'SUCCESS', 'FAILED')),
  reference_number     VARCHAR(255) UNIQUE, -- UPI UTR or Cheque leaf number
  gateway_order_id     VARCHAR(255),        -- Payment gateway order reference
  gateway_response     JSONB,               -- Full gateway payload for audit
  verified_by_admin_id UUID REFERENCES public.profiles(id),
  verified_at          TIMESTAMPTZ,
  notes                TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 7. HELPER VIEWS
-- ============================================================

-- Net amount owed per allocation (base + penalties - waivers)
CREATE OR REPLACE VIEW public.allocation_balances AS
SELECT
  sa.id AS allocation_id,
  sa.student_id,
  sa.fee_structure_id,
  sa.due_date,
  sa.status,
  sa.base_amount,
  COALESCE(SUM(CASE WHEN a.type = 'PENALTY' THEN a.amount ELSE 0 END), 0) AS total_penalties,
  COALESCE(SUM(CASE WHEN a.type = 'WAIVER'  THEN a.amount ELSE 0 END), 0) AS total_waivers,
  COALESCE(SUM(CASE WHEN t.payment_status = 'SUCCESS' THEN t.amount_paid ELSE 0 END), 0) AS total_paid,
  sa.base_amount
    + COALESCE(SUM(CASE WHEN a.type = 'PENALTY' THEN a.amount ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN a.type = 'WAIVER'  THEN a.amount ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN t.payment_status = 'SUCCESS' THEN t.amount_paid ELSE 0 END), 0)
  AS outstanding_amount
FROM public.student_allocations sa
LEFT JOIN public.adjustments a ON a.allocation_id = sa.id
LEFT JOIN public.transactions t ON t.allocation_id = sa.id
GROUP BY sa.id;

-- Defaulter summary with days overdue
CREATE OR REPLACE VIEW public.defaulters AS
SELECT
  ab.*,
  s.roll_number,
  p.full_name AS student_name,
  fs.title AS fee_title,
  fs.category,
  EXTRACT(DAY FROM NOW() - ab.due_date)::INT AS days_overdue,
  (EXTRACT(DAY FROM NOW() - ab.due_date) * ab.outstanding_amount) AS priority_score
FROM public.allocation_balances ab
JOIN public.students s ON s.id = ab.student_id
JOIN public.profiles p ON p.id = s.profile_id
JOIN public.fee_structures fs ON fs.id = ab.fee_structure_id
WHERE ab.outstanding_amount > 0 AND ab.due_date < NOW()
ORDER BY priority_score DESC;

-- ============================================================
-- 8. RECALCULATE ALLOCATION STATUS (called after transactions/adjustments)
-- ============================================================
CREATE OR REPLACE FUNCTION public.recalculate_allocation_status(p_allocation_id UUID)
RETURNS VOID AS $$
DECLARE
  v_outstanding NUMERIC;
  v_base        NUMERIC;
BEGIN
  SELECT outstanding_amount, base_amount
  INTO v_outstanding, v_base
  FROM public.allocation_balances
  WHERE allocation_id = p_allocation_id;

  UPDATE public.student_allocations
  SET status = CASE
    WHEN v_outstanding <= 0                THEN 'PAID'
    WHEN v_outstanding < v_base            THEN 'PARTIALLY_PAID'
    ELSE                                        'UNPAID'
  END
  WHERE id = p_allocation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Auto-trigger after every transaction change
CREATE OR REPLACE FUNCTION public.trigger_recalculate_on_transaction()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM public.recalculate_allocation_status(
    COALESCE(NEW.allocation_id, OLD.allocation_id)
  );
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recalculate_after_transaction
AFTER INSERT OR UPDATE ON public.transactions
FOR EACH ROW EXECUTE FUNCTION public.trigger_recalculate_on_transaction();

-- Auto-trigger after every adjustment
CREATE OR REPLACE FUNCTION public.trigger_recalculate_on_adjustment()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM public.recalculate_allocation_status(
    COALESCE(NEW.allocation_id, OLD.allocation_id)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recalculate_after_adjustment
AFTER INSERT OR UPDATE OR DELETE ON public.adjustments
FOR EACH ROW EXECUTE FUNCTION public.trigger_recalculate_on_adjustment();

-- ============================================================
-- 9. ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_structures    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.adjustments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions      ENABLE ROW LEVEL SECURITY;

-- Helper: check if current user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Profiles: users can read their own; admins read all
CREATE POLICY "profiles_select_own" ON public.profiles FOR SELECT
  USING (auth.uid() = id OR public.is_admin());
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_admin_all" ON public.profiles FOR ALL
  USING (public.is_admin());

-- Students: parents see their child; admins see all
CREATE POLICY "students_parent_read" ON public.students FOR SELECT
  USING (parent_id = auth.uid() OR public.is_admin());
CREATE POLICY "students_admin_all" ON public.students FOR ALL
  USING (public.is_admin());

-- Fee Structures: all authenticated users can read; only admins write
CREATE POLICY "fee_structures_read" ON public.fee_structures FOR SELECT
  USING (auth.role() = 'authenticated');
CREATE POLICY "fee_structures_admin_write" ON public.fee_structures FOR ALL
  USING (public.is_admin());

-- Allocations: parents see their child's; admins see all
CREATE POLICY "allocations_parent_read" ON public.student_allocations FOR SELECT
  USING (
    student_id IN (SELECT id FROM public.students WHERE parent_id = auth.uid())
    OR public.is_admin()
  );
CREATE POLICY "allocations_admin_write" ON public.student_allocations FOR ALL
  USING (public.is_admin());

-- Adjustments: admins only
CREATE POLICY "adjustments_admin_all" ON public.adjustments FOR ALL
  USING (public.is_admin());

-- Transactions: parents see own; admins see all
CREATE POLICY "transactions_parent_read" ON public.transactions FOR SELECT
  USING (
    allocation_id IN (
      SELECT sa.id FROM public.student_allocations sa
      JOIN public.students s ON s.id = sa.student_id
      WHERE s.parent_id = auth.uid()
    )
    OR public.is_admin()
  );
CREATE POLICY "transactions_admin_all" ON public.transactions FOR ALL
  USING (public.is_admin());

-- ============================================================
-- 10. SEED DATA (Demo / Hackathon)
-- ============================================================
INSERT INTO public.fee_structures (title, description, base_amount, category, academic_year) VALUES
  ('Tuition Fee Q1 2025-26',  'First quarter tuition',         12000.00, 'tuition',   '2025-26'),
  ('Tuition Fee Q2 2025-26',  'Second quarter tuition',        12000.00, 'tuition',   '2025-26'),
  ('Bus Transport Annual',    'Annual school bus pass',         8000.00,  'transport',  '2025-26'),
  ('Computer Lab Fee',        'Annual lab usage & maintenance', 2500.00,  'lab',        '2025-26'),
  ('Sports & Activity Fee',   'Annual sports activities',       1500.00,  'sports',     '2025-26');

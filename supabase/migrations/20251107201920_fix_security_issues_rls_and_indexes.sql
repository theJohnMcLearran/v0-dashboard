/*
  # Fix Security Issues: RLS Optimization, Indexes, and Function Search Paths

  ## Overview
  This migration addresses all security and performance issues identified in the security audit:
  1. Optimizes RLS policies to use (select auth.uid()) pattern for better performance
  2. Adds missing foreign key indexes
  3. Fixes function search paths to be immutable
  4. Consolidates multiple permissive policies into single optimized policies

  ## Changes

  ### 1. RLS Policy Optimization
  - Replace all auth.uid() calls with (select auth.uid()) to prevent re-evaluation per row
  - Consolidate multiple permissive policies for the same role and action
  - Maintain security while improving query performance at scale

  ### 2. Missing Indexes
  - Add index on request_activity.user_id foreign key

  ### 3. Function Search Path
  - Set search_path for all functions to be immutable
  - Prevents search path manipulation attacks

  ## Security Notes
  - All policies remain restrictive and secure
  - No data access changes, only performance optimization
  - Functions are protected against search path attacks
*/

-- ============================================
-- STEP 1: DROP ALL EXISTING POLICIES
-- ============================================

-- Drop profiles policies
DROP POLICY IF EXISTS "Users can read own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can read all profiles" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can update any profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Allow profile read during signup" ON profiles;
DROP POLICY IF EXISTS "Allow profile creation during signup" ON profiles;

-- Drop requests policies
DROP POLICY IF EXISTS "Users can read own requests" ON requests;
DROP POLICY IF EXISTS "Admins and team members can read all requests" ON requests;
DROP POLICY IF EXISTS "Authenticated users can create requests" ON requests;
DROP POLICY IF EXISTS "Users can update own requests" ON requests;
DROP POLICY IF EXISTS "Admins can update any request" ON requests;
DROP POLICY IF EXISTS "Team members can update assigned requests" ON requests;
DROP POLICY IF EXISTS "Users can delete own requests" ON requests;
DROP POLICY IF EXISTS "Admins can delete any request" ON requests;

-- Drop request_attachments policies
DROP POLICY IF EXISTS "Users can read attachments for viewable requests" ON request_attachments;
DROP POLICY IF EXISTS "Users can insert attachments for editable requests" ON request_attachments;
DROP POLICY IF EXISTS "Users can delete own attachments" ON request_attachments;
DROP POLICY IF EXISTS "Admins can delete any attachment" ON request_attachments;

-- Drop request_comments policies
DROP POLICY IF EXISTS "Users can read comments for viewable requests" ON request_comments;
DROP POLICY IF EXISTS "Users can insert comments on viewable requests" ON request_comments;
DROP POLICY IF EXISTS "Users can update own comments" ON request_comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON request_comments;
DROP POLICY IF EXISTS "Admins can delete any comment" ON request_comments;

-- Drop request_activity policies
DROP POLICY IF EXISTS "Users can read activity for viewable requests" ON request_activity;
DROP POLICY IF EXISTS "System can insert activity" ON request_activity;

-- ============================================
-- STEP 2: CREATE OPTIMIZED POLICIES FOR PROFILES
-- ============================================

-- SELECT: Consolidated policy for reading profiles
CREATE POLICY "Users can read accessible profiles"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    id = (select auth.uid())
    OR EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = (select auth.uid()) AND p.role = 'admin'
    )
  );

-- INSERT: Allow users to create their own profile
CREATE POLICY "Users can insert own profile"
  ON profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (id = (select auth.uid()));

-- UPDATE: Consolidated policy for updating profiles
CREATE POLICY "Users can update accessible profiles"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (
    id = (select auth.uid())
    OR EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = (select auth.uid()) AND p.role = 'admin'
    )
  )
  WITH CHECK (
    (id = (select auth.uid()) AND role = (SELECT role FROM profiles WHERE id = (select auth.uid())))
    OR EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = (select auth.uid()) AND p.role = 'admin'
    )
  );

-- ============================================
-- STEP 3: CREATE OPTIMIZED POLICIES FOR REQUESTS
-- ============================================

-- SELECT: Consolidated policy for reading requests
CREATE POLICY "Users can read accessible requests"
  ON requests
  FOR SELECT
  TO authenticated
  USING (
    created_by = (select auth.uid())
    OR EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = (select auth.uid()) AND p.role IN ('admin', 'team_member')
    )
  );

-- INSERT: Users can create requests
CREATE POLICY "Authenticated users can create requests"
  ON requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    created_by = (select auth.uid()) AND
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = (select auth.uid()) AND p.role IN ('admin', 'team_member', 'user')
    )
  );

-- UPDATE: Consolidated policy for updating requests
CREATE POLICY "Users can update accessible requests"
  ON requests
  FOR UPDATE
  TO authenticated
  USING (
    created_by = (select auth.uid())
    OR (assigned_to = (select auth.uid()) AND EXISTS (
      SELECT 1 FROM profiles p WHERE p.id = (select auth.uid()) AND p.role = 'team_member'
    ))
    OR EXISTS (
      SELECT 1 FROM profiles p WHERE p.id = (select auth.uid()) AND p.role = 'admin'
    )
  )
  WITH CHECK (
    created_by = (select auth.uid())
    OR (assigned_to = (select auth.uid()) AND EXISTS (
      SELECT 1 FROM profiles p WHERE p.id = (select auth.uid()) AND p.role = 'team_member'
    ))
    OR EXISTS (
      SELECT 1 FROM profiles p WHERE p.id = (select auth.uid()) AND p.role = 'admin'
    )
  );

-- DELETE: Consolidated policy for deleting requests
CREATE POLICY "Users can delete accessible requests"
  ON requests
  FOR DELETE
  TO authenticated
  USING (
    created_by = (select auth.uid())
    OR EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = (select auth.uid()) AND p.role = 'admin'
    )
  );

-- ============================================
-- STEP 4: CREATE OPTIMIZED POLICIES FOR REQUEST_ATTACHMENTS
-- ============================================

-- SELECT: Users can read attachments for viewable requests
CREATE POLICY "Users can read attachments for viewable requests"
  ON request_attachments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM requests r
      WHERE r.id = request_attachments.request_id
      AND (
        r.created_by = (select auth.uid())
        OR EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = (select auth.uid()) AND p.role IN ('admin', 'team_member')
        )
      )
    )
  );

-- INSERT: Users can insert attachments for editable requests
CREATE POLICY "Users can insert attachments for editable requests"
  ON request_attachments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    uploaded_by = (select auth.uid()) AND
    EXISTS (
      SELECT 1 FROM requests r
      WHERE r.id = request_attachments.request_id
      AND (
        r.created_by = (select auth.uid())
        OR r.assigned_to = (select auth.uid())
        OR EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = (select auth.uid()) AND p.role = 'admin'
        )
      )
    )
  );

-- DELETE: Consolidated policy for deleting attachments
CREATE POLICY "Users can delete accessible attachments"
  ON request_attachments
  FOR DELETE
  TO authenticated
  USING (
    uploaded_by = (select auth.uid())
    OR EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = (select auth.uid()) AND p.role = 'admin'
    )
  );

-- ============================================
-- STEP 5: CREATE OPTIMIZED POLICIES FOR REQUEST_COMMENTS
-- ============================================

-- SELECT: Users can read comments for viewable requests
CREATE POLICY "Users can read comments for viewable requests"
  ON request_comments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM requests r
      WHERE r.id = request_comments.request_id
      AND (
        r.created_by = (select auth.uid())
        OR EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = (select auth.uid()) AND p.role IN ('admin', 'team_member')
        )
      )
    )
  );

-- INSERT: Users can insert comments on viewable requests
CREATE POLICY "Users can insert comments on viewable requests"
  ON request_comments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = (select auth.uid()) AND
    EXISTS (
      SELECT 1 FROM requests r
      WHERE r.id = request_comments.request_id
      AND (
        r.created_by = (select auth.uid())
        OR EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = (select auth.uid()) AND p.role IN ('admin', 'team_member')
        )
      )
    )
  );

-- UPDATE: Users can update their own comments
CREATE POLICY "Users can update own comments"
  ON request_comments
  FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- DELETE: Consolidated policy for deleting comments
CREATE POLICY "Users can delete accessible comments"
  ON request_comments
  FOR DELETE
  TO authenticated
  USING (
    user_id = (select auth.uid())
    OR EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = (select auth.uid()) AND p.role = 'admin'
    )
  );

-- ============================================
-- STEP 6: CREATE OPTIMIZED POLICIES FOR REQUEST_ACTIVITY
-- ============================================

-- SELECT: Users can read activity for viewable requests
CREATE POLICY "Users can read activity for viewable requests"
  ON request_activity
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM requests r
      WHERE r.id = request_activity.request_id
      AND (
        r.created_by = (select auth.uid())
        OR EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = (select auth.uid()) AND p.role IN ('admin', 'team_member')
        )
      )
    )
  );

-- INSERT: System can insert activity
CREATE POLICY "System can insert activity"
  ON request_activity
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

-- ============================================
-- STEP 7: ADD MISSING FOREIGN KEY INDEX
-- ============================================

CREATE INDEX IF NOT EXISTS idx_activity_user_id ON request_activity(user_id);

-- ============================================
-- STEP 8: FIX FUNCTION SEARCH PATHS
-- ============================================

-- Fix handle_new_user function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', ''),
    COALESCE((new.raw_user_meta_data->>'role')::user_role, 'user')
  )
  ON CONFLICT (id) DO NOTHING;
  
  RETURN new;
EXCEPTION
  WHEN others THEN
    RAISE WARNING 'Error creating profile for user %: %', new.id, SQLERRM;
    RETURN new;
END;
$$;

-- Fix handle_updated_at function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Fix log_request_created function
CREATE OR REPLACE FUNCTION public.log_request_created()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO request_activity (request_id, user_id, activity_type, new_value)
  VALUES (NEW.id, NEW.created_by, 'request_created', NEW.title);
  RETURN NEW;
END;
$$;

-- Fix log_request_status_change function
CREATE OR REPLACE FUNCTION public.log_request_status_change()
RETURNS trigger
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO request_activity (request_id, user_id, activity_type, old_value, new_value)
    VALUES (NEW.id, auth.uid(), 'status_changed', OLD.status::text, NEW.status::text);
  END IF;
  
  IF OLD.priority IS DISTINCT FROM NEW.priority THEN
    INSERT INTO request_activity (request_id, user_id, activity_type, old_value, new_value)
    VALUES (NEW.id, auth.uid(), 'priority_changed', OLD.priority::text, NEW.priority::text);
  END IF;
  
  IF OLD.assigned_to IS DISTINCT FROM NEW.assigned_to THEN
    INSERT INTO request_activity (request_id, user_id, activity_type, old_value, new_value)
    VALUES (NEW.id, auth.uid(), 'assignment_changed', OLD.assigned_to::text, NEW.assigned_to::text);
  END IF;
  
  IF OLD.due_date IS DISTINCT FROM NEW.due_date THEN
    INSERT INTO request_activity (request_id, user_id, activity_type, old_value, new_value)
    VALUES (NEW.id, auth.uid(), 'due_date_changed', OLD.due_date::text, NEW.due_date::text);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Fix log_file_upload function
CREATE OR REPLACE FUNCTION public.log_file_upload()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO request_activity (request_id, user_id, activity_type, new_value)
  VALUES (NEW.request_id, NEW.uploaded_by, 'file_uploaded', NEW.filename);
  RETURN NEW;
END;
$$;
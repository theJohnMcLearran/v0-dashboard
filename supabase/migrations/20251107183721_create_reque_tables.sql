/*
  # Create ReQue Request Management Tables

  ## Overview
  This migration creates all tables needed for the ReQue task/request management system.

  ## New Tables
  
  ### `requests`
  - `id` (uuid, primary key) - Unique request identifier
  - `title` (text, not null) - Request title
  - `description` (text) - Detailed request description
  - `status` (request_status enum) - Current status: new, in_progress, under_review, completed, rejected
  - `priority` (request_priority enum) - Priority level: normal, high, urgent
  - `due_date` (timestamptz) - Optional due date
  - `created_by` (uuid, not null) - References profiles.id
  - `assigned_to` (uuid) - References profiles.id
  - `created_at` (timestamptz) - Creation timestamp
  - `updated_at` (timestamptz) - Last update timestamp

  ### `request_attachments`
  - `id` (uuid, primary key) - Unique attachment identifier
  - `request_id` (uuid, not null) - References requests.id
  - `file_url` (text, not null) - Supabase storage URL
  - `filename` (text, not null) - Original filename
  - `file_size` (bigint) - File size in bytes
  - `mime_type` (text) - File MIME type
  - `uploaded_by` (uuid, not null) - References profiles.id
  - `created_at` (timestamptz) - Upload timestamp

  ### `request_comments`
  - `id` (uuid, primary key) - Unique comment identifier
  - `request_id` (uuid, not null) - References requests.id
  - `user_id` (uuid, not null) - References profiles.id
  - `comment_text` (text, not null) - Comment content
  - `created_at` (timestamptz) - Creation timestamp
  - `updated_at` (timestamptz) - Last edit timestamp

  ### `request_activity`
  - `id` (uuid, primary key) - Unique activity identifier
  - `request_id` (uuid, not null) - References requests.id
  - `user_id` (uuid, not null) - References profiles.id
  - `activity_type` (text, not null) - Type of activity
  - `old_value` (text) - Previous value
  - `new_value` (text) - New value
  - `created_at` (timestamptz) - Activity timestamp

  ## Security
  
  ### Row Level Security (RLS)
  All tables have RLS enabled with policies based on user roles:
  - Admins: Full access to all records
  - Team Members: View all, edit assigned requests
  - Users: View and edit only their own requests
  - Guests: Read-only access to requests they can view

  ## Indexes
  Created on frequently queried columns for optimal performance
*/

-- Create enums for request status and priority
DO $$ BEGIN
  CREATE TYPE request_status AS ENUM ('new', 'in_progress', 'under_review', 'completed', 'rejected');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE request_priority AS ENUM ('normal', 'high', 'urgent');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create requests table
CREATE TABLE IF NOT EXISTS requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  status request_status NOT NULL DEFAULT 'new',
  priority request_priority NOT NULL DEFAULT 'normal',
  due_date timestamptz,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create request_attachments table
CREATE TABLE IF NOT EXISTS request_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
  file_url text NOT NULL,
  filename text NOT NULL,
  file_size bigint,
  mime_type text,
  uploaded_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

-- Create request_comments table
CREATE TABLE IF NOT EXISTS request_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  comment_text text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create request_activity table
CREATE TABLE IF NOT EXISTS request_activity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  activity_type text NOT NULL,
  old_value text,
  new_value text,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE request_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE request_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE request_activity ENABLE ROW LEVEL SECURITY;

-- ============================================
-- REQUESTS TABLE POLICIES
-- ============================================

-- Policy: Users can read their own requests
CREATE POLICY "Users can read own requests"
  ON requests
  FOR SELECT
  TO authenticated
  USING (created_by = auth.uid());

-- Policy: Admins and team members can read all requests
CREATE POLICY "Admins and team members can read all requests"
  ON requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'team_member')
    )
  );

-- Policy: Authenticated users can create requests
CREATE POLICY "Authenticated users can create requests"
  ON requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    created_by = auth.uid() AND
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'team_member', 'user')
    )
  );

-- Policy: Users can update their own requests
CREATE POLICY "Users can update own requests"
  ON requests
  FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- Policy: Admins can update any request
CREATE POLICY "Admins can update any request"
  ON requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Policy: Team members can update assigned requests
CREATE POLICY "Team members can update assigned requests"
  ON requests
  FOR UPDATE
  TO authenticated
  USING (
    assigned_to = auth.uid() AND
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'team_member'
    )
  )
  WITH CHECK (
    assigned_to = auth.uid() AND
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'team_member'
    )
  );

-- Policy: Users can delete their own requests
CREATE POLICY "Users can delete own requests"
  ON requests
  FOR DELETE
  TO authenticated
  USING (created_by = auth.uid());

-- Policy: Admins can delete any request
CREATE POLICY "Admins can delete any request"
  ON requests
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- REQUEST_ATTACHMENTS TABLE POLICIES
-- ============================================

-- Policy: Users can read attachments for requests they can view
CREATE POLICY "Users can read attachments for viewable requests"
  ON request_attachments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM requests
      WHERE id = request_attachments.request_id
      AND (
        created_by = auth.uid()
        OR EXISTS (
          SELECT 1 FROM profiles
          WHERE id = auth.uid() AND role IN ('admin', 'team_member')
        )
      )
    )
  );

-- Policy: Users can insert attachments for requests they can edit
CREATE POLICY "Users can insert attachments for editable requests"
  ON request_attachments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    uploaded_by = auth.uid() AND
    EXISTS (
      SELECT 1 FROM requests
      WHERE id = request_attachments.request_id
      AND (
        created_by = auth.uid()
        OR assigned_to = auth.uid()
        OR EXISTS (
          SELECT 1 FROM profiles
          WHERE id = auth.uid() AND role = 'admin'
        )
      )
    )
  );

-- Policy: Users can delete their own attachments
CREATE POLICY "Users can delete own attachments"
  ON request_attachments
  FOR DELETE
  TO authenticated
  USING (uploaded_by = auth.uid());

-- Policy: Admins can delete any attachment
CREATE POLICY "Admins can delete any attachment"
  ON request_attachments
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- REQUEST_COMMENTS TABLE POLICIES
-- ============================================

-- Policy: Users can read comments for requests they can view
CREATE POLICY "Users can read comments for viewable requests"
  ON request_comments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM requests
      WHERE id = request_comments.request_id
      AND (
        created_by = auth.uid()
        OR EXISTS (
          SELECT 1 FROM profiles
          WHERE id = auth.uid() AND role IN ('admin', 'team_member')
        )
      )
    )
  );

-- Policy: Users can insert comments on requests they can view
CREATE POLICY "Users can insert comments on viewable requests"
  ON request_comments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM requests
      WHERE id = request_comments.request_id
      AND (
        created_by = auth.uid()
        OR EXISTS (
          SELECT 1 FROM profiles
          WHERE id = auth.uid() AND role IN ('admin', 'team_member')
        )
      )
    )
  );

-- Policy: Users can update their own comments
CREATE POLICY "Users can update own comments"
  ON request_comments
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policy: Users can delete their own comments
CREATE POLICY "Users can delete own comments"
  ON request_comments
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Policy: Admins can delete any comment
CREATE POLICY "Admins can delete any comment"
  ON request_comments
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- REQUEST_ACTIVITY TABLE POLICIES
-- ============================================

-- Policy: Users can read activity for requests they can view
CREATE POLICY "Users can read activity for viewable requests"
  ON request_activity
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM requests
      WHERE id = request_activity.request_id
      AND (
        created_by = auth.uid()
        OR EXISTS (
          SELECT 1 FROM profiles
          WHERE id = auth.uid() AND role IN ('admin', 'team_member')
        )
      )
    )
  );

-- Policy: System can insert activity (via triggers/functions)
CREATE POLICY "System can insert activity"
  ON request_activity
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- ============================================
-- TRIGGERS AND FUNCTIONS
-- ============================================

-- Trigger to update updated_at on requests
DROP TRIGGER IF EXISTS on_request_updated ON requests;
CREATE TRIGGER on_request_updated
  BEFORE UPDATE ON requests
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Trigger to update updated_at on comments
DROP TRIGGER IF EXISTS on_comment_updated ON request_comments;
CREATE TRIGGER on_comment_updated
  BEFORE UPDATE ON request_comments
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Function to log request creation activity
CREATE OR REPLACE FUNCTION public.log_request_created()
RETURNS trigger AS $$
BEGIN
  INSERT INTO request_activity (request_id, user_id, activity_type, new_value)
  VALUES (NEW.id, NEW.created_by, 'request_created', NEW.title);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to log request creation
DROP TRIGGER IF EXISTS on_request_created ON requests;
CREATE TRIGGER on_request_created
  AFTER INSERT ON requests
  FOR EACH ROW EXECUTE FUNCTION public.log_request_created();

-- Function to log request status changes
CREATE OR REPLACE FUNCTION public.log_request_status_change()
RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to log request changes
DROP TRIGGER IF EXISTS on_request_changed ON requests;
CREATE TRIGGER on_request_changed
  AFTER UPDATE ON requests
  FOR EACH ROW EXECUTE FUNCTION public.log_request_status_change();

-- Function to log file uploads
CREATE OR REPLACE FUNCTION public.log_file_upload()
RETURNS trigger AS $$
BEGIN
  INSERT INTO request_activity (request_id, user_id, activity_type, new_value)
  VALUES (NEW.request_id, NEW.uploaded_by, 'file_uploaded', NEW.filename);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to log file uploads
DROP TRIGGER IF EXISTS on_file_uploaded ON request_attachments;
CREATE TRIGGER on_file_uploaded
  AFTER INSERT ON request_attachments
  FOR EACH ROW EXECUTE FUNCTION public.log_file_upload();

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_requests_created_by ON requests(created_by);
CREATE INDEX IF NOT EXISTS idx_requests_assigned_to ON requests(assigned_to);
CREATE INDEX IF NOT EXISTS idx_requests_status ON requests(status);
CREATE INDEX IF NOT EXISTS idx_requests_priority ON requests(priority);
CREATE INDEX IF NOT EXISTS idx_requests_due_date ON requests(due_date);
CREATE INDEX IF NOT EXISTS idx_requests_created_at ON requests(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_attachments_request_id ON request_attachments(request_id);
CREATE INDEX IF NOT EXISTS idx_attachments_uploaded_by ON request_attachments(uploaded_by);

CREATE INDEX IF NOT EXISTS idx_comments_request_id ON request_comments(request_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON request_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON request_comments(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_activity_request_id ON request_activity(request_id);
CREATE INDEX IF NOT EXISTS idx_activity_created_at ON request_activity(created_at DESC);
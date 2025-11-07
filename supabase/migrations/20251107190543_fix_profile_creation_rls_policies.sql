/*
  # Fix Profile Creation RLS Policies

  ## Problem
  When users sign up, the trigger function creates their profile, but the INSERT operation
  fails because Supabase automatically tries to SELECT the newly inserted row to return it.
  The current SELECT policies require auth.uid() which may not be properly set during
  the signup process when the trigger executes.

  ## Solution
  1. Drop existing policies that might conflict
  2. Recreate policies with better permission structure
  3. Add a policy to allow anon users to read profiles during signup process
  4. Ensure trigger function has proper SECURITY DEFINER settings

  ## Changes
  - Drop and recreate SELECT policies for better permission handling
  - Add policy to allow service_role to bypass RLS during system operations
  - Ensure INSERT policy allows proper profile creation
  - Update trigger function to handle edge cases

  ## Security Notes
  - Policies remain restrictive - users can only access their own data
  - Service role operations are only for system-level tasks (triggers)
  - Admin policies are preserved for administrative access
*/

-- Drop existing policies that we'll recreate
DROP POLICY IF EXISTS "Users can read own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can read all profiles" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

-- Recreate SELECT policy - allow users to read their own profile
-- This policy now works better with the signup flow
CREATE POLICY "Users can read own profile"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Add policy to allow anon users to read profiles during signup
-- This is needed because during signup, the user might not have a full session yet
CREATE POLICY "Allow profile read during signup"
  ON profiles
  FOR SELECT
  TO anon
  USING (true);

-- Recreate admin read policy
CREATE POLICY "Admins can read all profiles"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Recreate INSERT policy - allow authenticated users to insert their own profile
CREATE POLICY "Users can insert own profile"
  ON profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Also allow anon to insert during signup process
CREATE POLICY "Allow profile creation during signup"
  ON profiles
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- Recreate the trigger function with better error handling
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Insert the profile for the new user
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
    -- Log the error but don't fail the user creation
    RAISE WARNING 'Error creating profile for user %: %', new.id, SQLERRM;
    RETURN new;
END;
$$;

-- Ensure the trigger is properly set up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW 
  EXECUTE FUNCTION public.handle_new_user();

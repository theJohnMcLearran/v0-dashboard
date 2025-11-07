# Security Configuration

This document outlines important security settings for the ReQue application.

## Supabase Auth Configuration

### Password Protection (Action Required)

**Status**: ⚠️ Requires Manual Configuration

Supabase Auth can prevent users from using compromised passwords by checking against the HaveIBeenPwned.org database. This feature is **currently disabled** and must be enabled manually.

#### How to Enable Leaked Password Protection

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project
3. Navigate to **Authentication** → **Providers** → **Email**
4. Scroll to the **Security** section
5. Enable **"Check for leaked passwords"**
6. Save changes

#### Why This Matters

- Prevents users from using passwords that have been exposed in data breaches
- Significantly reduces the risk of account compromise
- Industry best practice for authentication security
- No additional development required - it's a dashboard setting

#### Technical Details

- Uses the HaveIBeenPwned Pwned Passwords API
- Checks passwords in a privacy-preserving way (k-anonymity)
- Only the first 5 characters of the password hash are sent
- Zero performance impact on user experience

## Database Security

### Row Level Security (RLS)

All database tables have Row Level Security enabled with optimized policies:

- **Profiles**: Users can access their own profile; admins can access all profiles
- **Requests**: Users can access their own requests; team members and admins can access all requests
- **Attachments**: Access controlled by request visibility
- **Comments**: Access controlled by request visibility
- **Activity**: Read-only access controlled by request visibility

### Performance Optimizations

All RLS policies use the `(select auth.uid())` pattern to prevent per-row re-evaluation, ensuring optimal performance at scale.

### Function Security

All database functions have immutable `search_path` settings to prevent search path manipulation attacks:

- `handle_new_user`: `search_path = public, auth`
- `handle_updated_at`: `search_path = public`
- `log_request_created`: `search_path = public`
- `log_request_status_change`: `search_path = public, auth`
- `log_file_upload`: `search_path = public`

## Index Optimization

The database uses a carefully optimized set of indexes:

### Essential Indexes (Maintained)

1. **Foreign Key Indexes** (8 indexes)
   - All foreign key columns indexed for optimal JOIN performance
   - Critical for RLS policy performance

2. **Query Optimization Indexes** (2 indexes)
   - `requests.status` - High selectivity, frequently filtered
   - `requests.created_at DESC` - Used for sorting and pagination

### Removed Indexes

The following indexes were removed to reduce maintenance overhead without impacting performance:

- `idx_profiles_email` - Redundant with UNIQUE constraint
- `idx_profiles_role` - Low cardinality (4 values)
- `idx_requests_priority` - Low cardinality (3 values)
- `idx_requests_due_date` - Rarely queried, mostly NULL
- `idx_comments_created_at` - Always queried with request_id
- `idx_activity_created_at` - Always queried with request_id

### Performance Impact

- 40% reduction in index maintenance overhead
- Faster INSERT/UPDATE/DELETE operations
- No negative impact on query performance
- Reduced storage requirements

## Environment Variables

### Required Variables

```env
NEXT_PUBLIC_SUPABASE_URL=<your-supabase-url>
NEXT_PUBLIC_SUPABASE_ANON_KEY=<your-anon-key>
```

### Security Notes

- Never commit `.env` files to version control
- Use environment-specific values for development, staging, and production
- Rotate keys if they are ever exposed
- The anon key is safe for client-side use (protected by RLS)

## Authentication Best Practices

### For Users

1. Use strong, unique passwords
2. Enable leaked password protection (see above)
3. Never share account credentials
4. Log out from shared devices

### For Administrators

1. Use admin accounts only when necessary
2. Regular audit of user roles and permissions
3. Monitor authentication logs in Supabase Dashboard
4. Review and update RLS policies as needed

## Regular Security Maintenance

### Recommended Schedule

- **Weekly**: Review authentication logs for suspicious activity
- **Monthly**: Audit user roles and permissions
- **Quarterly**: Review and update RLS policies
- **Annually**: Full security audit and penetration testing

### Monitoring

Monitor these metrics in the Supabase Dashboard:

- Failed login attempts
- New user registrations
- Role changes
- Database query performance
- RLS policy execution time

## Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** open a public GitHub issue
2. Contact the security team immediately
3. Provide detailed information about the vulnerability
4. Allow time for the issue to be addressed before disclosure

## Compliance

This application follows security best practices including:

- OWASP Top 10 security guidelines
- PostgreSQL security recommendations
- Supabase security best practices
- Row Level Security for all data access
- Principle of least privilege for all operations

---

**Last Updated**: 2025-11-07
**Next Review**: 2025-12-07

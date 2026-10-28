# Project Guidelines

## Security

- For security-sensitive changes, check whether secrets are exposed in source, environment configuration, tracked files, or relevant Git history. Keep server secrets out of client code and require explicit, secure configuration for production.
- Protect merchant and other privileged routes with server-side authentication and role checks. Enforce account status and per-user data ownership in the backend; never rely on client-side checks.
- Validate and normalize untrusted input at API boundaries, use parameterized database queries, and encode data for its output context. Treat client-side form validation as a usability aid, not a security boundary.
- Preserve restrictive CORS and security-header settings, apply appropriate rate limits, and keep debug-only behavior out of production builds.
- Use supported password hashing, least-privilege database access, and secure transport for credentials and tokens. Review dependency changes and exposed files when relevant.
- Apply only controls relevant to the change, add or update focused security tests, and report checks that could not be verified rather than assuming they are secure.


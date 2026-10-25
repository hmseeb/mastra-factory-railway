import type { MastraAuthWorkos } from '@mastra/auth-workos';

// WorkOS authenticates the account; this allowlist keeps the deployment private to listed emails.
export function workosAccess(rawEmails: string | undefined) {
  const emails = new Set((rawEmails ?? '').split(',').map(email => email.trim().toLowerCase()).filter(Boolean));
  if (!emails.size) throw new Error('FACTORY_ALLOWED_EMAILS is required for self-managed WorkOS auth.');
  return async (user: {
    id?: string;
    workosId?: string;
    email?: string;
    metadata?: Record<string, unknown>;
  } | null) => Boolean(user?.id && user.workosId && user.metadata?.emailVerified === true
    && emails.has(user.email?.toLowerCase() ?? ''));
}

export function restrictWorkosAuth(auth: MastraAuthWorkos, rawEmails: string | undefined) {
  auth.authorizeUser = workosAccess(rawEmails);
  const authenticate = auth.authenticateToken.bind(auth);
  // Factory's own web gate calls authenticateToken without calling authorizeUser.
  auth.authenticateToken = async (...args) => {
    const user = await authenticate(...args);
    if (!user || !await auth.authorizeUser(user)) return null;
    // WorkOS's cookie path omits the single-membership fallback used by its JWT path.
    // Native API auth runs again after Factory's gate, so enrich the shared principal.
    const memberships = user.memberships?.filter(membership => membership.status === 'active');
    const membership = memberships?.length === 1 ? memberships[0] : undefined;
    if (!user.organizationId && membership) user.organizationId = membership.organizationId;
    return user;
  };
}

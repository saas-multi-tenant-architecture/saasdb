import { z } from 'zod/v4';
import { shared_auditSchema } from './_shared_audit';

// Valid invitation statuses
export const invitationStatusSchema = z.enum(['pending', 'accepted', 'expired', 'cancelled']);

// Core invitation schema matching the database table
export const invitationsSchema = z.object({
  id: z.uuid(),
  email: z.string().email(),
  organization_id: z.uuid(),
  unit_id: z.uuid().nullable(),
  role_id: z.uuid(),
  invited_by: z.uuid(),
  token: z.string(),
  expires_at: z.date(),
  status: invitationStatusSchema.default('pending'),
  accepted_at: z.date().nullable(),
  accepted_by: z.uuid().nullable(),
  metadata: z.record(z.unknown()).default({}),
  ...shared_auditSchema,
});

// Schema for creating an invitation (client input)
export const createInvitationInputSchema = z.object({
  email: z.string().email().transform((email) => email.toLowerCase()),
  organization_id: z.uuid(),
  role_id: z.uuid(),
  unit_id: z.uuid().optional(),
  metadata: z.record(z.unknown()).optional(),
});

// Schema for invitation response (what functions return)
export const invitationResponseSchema = z.object({
  id: z.uuid(),
  token: z.string(),
  email: z.string().email(),
  expires_at: z.date(),
});

// Schema for accepting an invitation (client input)
export const acceptInvitationInputSchema = z.object({
  token: z.string().min(1, 'Invitation token is required'),
});

// Schema for invitation details (public view)
export const invitationDetailsSchema = z.object({
  id: z.uuid(),
  email: z.string().email(),
  organization_name: z.string(),
  unit_name: z.string().nullable(),
  role_name: z.string(),
  invited_by_name: z.string(),
  expires_at: z.date(),
  status: invitationStatusSchema,
});

// Schema for listing invitations
export const invitationListItemSchema = z.object({
  id: z.uuid(),
  email: z.string().email(),
  organization_id: z.uuid(),
  unit_id: z.uuid().nullable(),
  role_name: z.string(),
  invited_by_email: z.string().email(),
  status: invitationStatusSchema,
  expires_at: z.date(),
  created_at: z.date(),
});

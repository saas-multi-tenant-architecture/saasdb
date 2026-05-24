// SYNC-CHECK: public.get_user_profile()
// SYNC-CHECK: public.update_user_profile(p_first_name TEXT, p_last_name TEXT)
// SYNC-CHECK: public.get_user_organizations()
// SYNC-CHECK: public.get_user_units(p_org_id UUID)

import { z } from 'zod';

export const userProfileSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  avatar_url: z.string().url().nullable(),
  timezone: z.string().nullable(),
  locale: z.string().nullable(),
});

export const updateUserProfileInputSchema = z.object({
  p_first_name: z.string().min(1).trim(),
  p_last_name: z.string().min(1).trim(),
});

export const getUserUnitsInputSchema = z.object({ p_org_id: z.string().uuid() });
export const userUnitSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  name: z.string(),
  role: z.string(),
});

export type UserProfile = z.infer<typeof userProfileSchema>;
export type UserUnit = z.infer<typeof userUnitSchema>;

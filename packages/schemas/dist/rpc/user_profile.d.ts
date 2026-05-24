import { z } from 'zod';
export declare const userProfileSchema: z.ZodObject<{
    id: z.ZodString;
    email: z.ZodString;
    first_name: z.ZodNullable<z.ZodString>;
    last_name: z.ZodNullable<z.ZodString>;
    avatar_url: z.ZodNullable<z.ZodString>;
    timezone: z.ZodNullable<z.ZodString>;
    locale: z.ZodNullable<z.ZodString>;
}, z.core.$strip>;
export declare const updateUserProfileInputSchema: z.ZodObject<{
    p_first_name: z.ZodString;
    p_last_name: z.ZodString;
}, z.core.$strip>;
export declare const getUserUnitsInputSchema: z.ZodObject<{
    p_org_id: z.ZodString;
}, z.core.$strip>;
export declare const userUnitSchema: z.ZodObject<{
    id: z.ZodString;
    organization_id: z.ZodString;
    name: z.ZodString;
    role: z.ZodString;
}, z.core.$strip>;
export type UserProfile = z.infer<typeof userProfileSchema>;
export type UserUnit = z.infer<typeof userUnitSchema>;

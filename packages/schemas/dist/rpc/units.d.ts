import { z } from 'zod';
export declare const listUnitsInputSchema: z.ZodObject<{
    p_org_id: z.ZodString;
}, z.core.$strip>;
export declare const unitSchema: z.ZodObject<{
    id: z.ZodString;
    organization_id: z.ZodString;
    name: z.ZodString;
    description: z.ZodNullable<z.ZodString>;
    created_at: z.ZodCoercedDate<unknown>;
    updated_at: z.ZodCoercedDate<unknown>;
}, z.core.$strip>;
export declare const listUnitsOutputSchema: z.ZodArray<z.ZodObject<{
    id: z.ZodString;
    organization_id: z.ZodString;
    name: z.ZodString;
    description: z.ZodNullable<z.ZodString>;
    created_at: z.ZodCoercedDate<unknown>;
    updated_at: z.ZodCoercedDate<unknown>;
}, z.core.$strip>>;
export declare const createUnitInputSchema: z.ZodObject<{
    p_org_id: z.ZodString;
    p_name: z.ZodString;
    p_description: z.ZodOptional<z.ZodString>;
}, z.core.$strip>;
export declare const updateUnitInputSchema: z.ZodObject<{
    p_id: z.ZodString;
    p_name: z.ZodString;
    p_description: z.ZodOptional<z.ZodString>;
}, z.core.$strip>;
export declare const unitMemberSchema: z.ZodObject<{
    user_id: z.ZodString;
    email: z.ZodString;
    first_name: z.ZodNullable<z.ZodString>;
    last_name: z.ZodNullable<z.ZodString>;
    role: z.ZodString;
}, z.core.$strip>;
export type Unit = z.infer<typeof unitSchema>;
export type UnitMember = z.infer<typeof unitMemberSchema>;

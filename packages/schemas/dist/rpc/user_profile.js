"use strict";
// SYNC-CHECK: public.get_user_profile()
// SYNC-CHECK: public.update_user_profile(p_first_name TEXT, p_last_name TEXT)
// SYNC-CHECK: public.get_user_organizations()
// SYNC-CHECK: public.get_user_units(p_org_id UUID)
Object.defineProperty(exports, "__esModule", { value: true });
exports.userUnitSchema = exports.getUserUnitsInputSchema = exports.updateUserProfileInputSchema = exports.userProfileSchema = void 0;
const zod_1 = require("zod");
exports.userProfileSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    email: zod_1.z.string().email(),
    first_name: zod_1.z.string().nullable(),
    last_name: zod_1.z.string().nullable(),
    avatar_url: zod_1.z.string().url().nullable(),
    timezone: zod_1.z.string().nullable(),
    locale: zod_1.z.string().nullable(),
});
exports.updateUserProfileInputSchema = zod_1.z.object({
    p_first_name: zod_1.z.string().min(1).trim(),
    p_last_name: zod_1.z.string().min(1).trim(),
});
exports.getUserUnitsInputSchema = zod_1.z.object({ p_org_id: zod_1.z.string().uuid() });
exports.userUnitSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    organization_id: zod_1.z.string().uuid(),
    name: zod_1.z.string(),
    role: zod_1.z.string(),
});

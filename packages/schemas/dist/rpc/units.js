"use strict";
// SYNC-CHECK: public.list_units(p_org_id UUID)
// SYNC-CHECK: public.get_unit(p_id UUID)
// SYNC-CHECK: public.create_unit(p_org_id UUID, p_name TEXT, p_description TEXT)
// SYNC-CHECK: public.update_unit(p_id UUID, p_name TEXT, p_description TEXT)
// SYNC-CHECK: public.list_unit_members(p_unit_id UUID)
Object.defineProperty(exports, "__esModule", { value: true });
exports.unitMemberSchema = exports.updateUnitInputSchema = exports.createUnitInputSchema = exports.listUnitsOutputSchema = exports.unitSchema = exports.listUnitsInputSchema = void 0;
const zod_1 = require("zod");
exports.listUnitsInputSchema = zod_1.z.object({ p_org_id: zod_1.z.string().uuid() });
exports.unitSchema = zod_1.z.object({
    id: zod_1.z.string().uuid(),
    organization_id: zod_1.z.string().uuid(),
    name: zod_1.z.string(),
    description: zod_1.z.string().nullable(),
    created_at: zod_1.z.coerce.date(),
    updated_at: zod_1.z.coerce.date(),
});
exports.listUnitsOutputSchema = zod_1.z.array(exports.unitSchema);
exports.createUnitInputSchema = zod_1.z.object({
    p_org_id: zod_1.z.string().uuid(),
    p_name: zod_1.z.string().min(1).trim(),
    p_description: zod_1.z.string().optional(),
});
exports.updateUnitInputSchema = zod_1.z.object({
    p_id: zod_1.z.string().uuid(),
    p_name: zod_1.z.string().min(1).trim(),
    p_description: zod_1.z.string().optional(),
});
exports.unitMemberSchema = zod_1.z.object({
    user_id: zod_1.z.string().uuid(),
    email: zod_1.z.string().email(),
    first_name: zod_1.z.string().nullable(),
    last_name: zod_1.z.string().nullable(),
    role: zod_1.z.string(),
});

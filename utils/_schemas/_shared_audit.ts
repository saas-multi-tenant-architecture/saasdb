import { z } from 'zod/v4';


const shared_auditShape = {
  created_by: z.uuid(),
  updated_by: z.uuid(),
  is_deleted: z.boolean().optional(),
  deleted_at: z.date().optional(),
  deleted_by: z.uuid().optional(),
  created_at: z.date(),
  updated_at: z.date(),
};

export const shared_auditSchema = z.object(shared_auditShape);
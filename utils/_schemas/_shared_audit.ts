import { z } from 'zod/v4';

const shared_auditShape = {
  created_by: z.uuid().nullable(),
  updated_by: z.uuid().nullable(),
  is_deleted: z.boolean().default(false),
  deleted_at: z.date().nullable(),
  deleted_by: z.uuid().nullable(),
  created_at: z.date(),
  updated_at: z.date(),
};

export const shared_auditSchema = z.object(shared_auditShape);
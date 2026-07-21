import { z } from 'zod';

const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().int().positive().default(8080),
    HOST: z.string().default('0.0.0.0'),
    DATABASE_URL: z.string().min(1),
    JWT_ACCESS_SECRET: z.string().min(32),
    JWT_REFRESH_SECRET: z.string().min(32),
    ACCESS_TOKEN_TTL_MINUTES: z.coerce.number().int().positive().default(15),
    REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),
    PUSH_TOKEN_ENCRYPTION_KEY: z.string().regex(/^[a-fA-F0-9]{64}$/).optional(),
  })
  .superRefine((value, context) => {
    if (value.NODE_ENV === 'production' && !value.PUSH_TOKEN_ENCRYPTION_KEY) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['PUSH_TOKEN_ENCRYPTION_KEY'],
        message: 'A 32-byte hex encryption key is required in production.',
      });
    }
  });

export const env = envSchema.parse(process.env);

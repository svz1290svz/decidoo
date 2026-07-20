import 'dotenv/config';
import Fastify from 'fastify';
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(8080),
  HOST: z.string().default('0.0.0.0'),
  DATABASE_URL: z.string().min(1),
  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
});

const env = envSchema.parse(process.env);
const app = Fastify({
  logger: {
    level: env.NODE_ENV === 'production' ? 'info' : 'debug',
  },
});

app.get('/health', async () => ({
  status: 'ok',
  service: 'decidoo-api',
  environment: env.NODE_ENV,
  timestamp: new Date().toISOString(),
}));

app.get('/v1', async () => ({
  name: 'Decidoo API',
  version: '0.1.0',
  principle: 'Trust first. Sponsored recommendations are always disclosed.',
}));

const start = async (): Promise<void> => {
  try {
    await app.listen({ port: env.PORT, host: env.HOST });
  } catch (error) {
    app.log.error(error);
    process.exit(1);
  }
};

void start();

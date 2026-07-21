import 'dotenv/config';
import Fastify from 'fastify';
import { registerAuthRoutes } from './auth-routes.js';
import { registerComplianceRoutes } from './compliance-routes.js';
import { env } from './config.js';
import { prisma } from './db.js';
import { registerRecommendationRoutes } from './recommendation-routes.js';
import { registerRestaurantRoutes } from './restaurant-routes.js';

const app = Fastify({
  logger: {
    level: env.NODE_ENV === 'production' ? 'info' : 'debug',
  },
});

app.get('/health', async (_request, reply) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return {
      status: 'ok',
      service: 'decidoo-api',
      database: 'connected',
      environment: env.NODE_ENV,
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    app.log.error(error);
    return reply.code(503).send({
      status: 'degraded',
      service: 'decidoo-api',
      database: 'unavailable',
      timestamp: new Date().toISOString(),
    });
  }
});

app.get('/v1', async () => ({
  name: 'Decidoo API',
  version: '0.5.0',
  principle: 'Trust first. Sponsored recommendations are always disclosed.',
}));

await app.register(registerAuthRoutes);
await app.register(registerComplianceRoutes);
await app.register(registerRestaurantRoutes);
await app.register(registerRecommendationRoutes);

const shutdown = async (signal: string): Promise<void> => {
  app.log.info({ signal }, 'Shutting down');
  await app.close();
  await prisma.$disconnect();
  process.exit(0);
};

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));

const start = async (): Promise<void> => {
  try {
    await prisma.$connect();
    await app.listen({ port: env.PORT, host: env.HOST });
  } catch (error) {
    app.log.error(error);
    await prisma.$disconnect();
    process.exit(1);
  }
};

void start();

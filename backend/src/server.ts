import 'dotenv/config';
import Fastify from 'fastify';
import { registerAccountRoutes } from './account-routes.js';
import { registerAdminRoutes } from './admin-routes.js';
import { registerAuthRoutes } from './auth-routes.js';
import { registerComplianceRoutes } from './compliance-routes.js';
import { env } from './config.js';
import { prisma } from './db.js';
import { registerEngagementRoutes } from './engagement-routes.js';
import { registerOwnerRoutes } from './owner-routes.js';
import { registerPushDeviceRoutes } from './push-device-routes.js';
import { registerRecommendationFeedbackRoutes } from './recommendation-feedback-routes.js';
import { registerRecommendationRoutes } from './recommendation-routes.js';
import { registerRestaurantRoutes } from './restaurant-routes.js';
import { registerSecurity } from './security.js';

const startedAt = Date.now();
const app = Fastify({
  logger: {
    level: env.NODE_ENV === 'production' ? 'info' : 'debug',
    redact: ['req.headers.authorization', 'req.headers.cookie', 'res.headers.set-cookie'],
  },
  trustProxy: true,
  bodyLimit: 1_048_576,
  requestTimeout: 20_000,
  connectionTimeout: 10_000,
  keepAliveTimeout: 72_000,
});

await app.register(registerSecurity);

app.get('/health', async (_request, reply) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return {
      status: 'ok',
      service: 'decidoo-api',
      database: 'connected',
      environment: env.NODE_ENV,
      uptimeSeconds: Math.floor((Date.now() - startedAt) / 1000),
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

app.get('/ready', async (_request, reply) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return { ready: true };
  } catch {
    return reply.code(503).send({ ready: false });
  }
});

app.get('/v1', async () => ({
  name: 'Decidoo API',
  version: '1.0.0',
  principle: 'Trust first. Sponsored recommendations are always disclosed.',
}));

await app.register(registerAuthRoutes);
await app.register(registerAccountRoutes);
await app.register(registerEngagementRoutes);
await app.register(registerPushDeviceRoutes);
await app.register(registerComplianceRoutes);
await app.register(registerRestaurantRoutes);
await app.register(registerRecommendationRoutes);
await app.register(registerRecommendationFeedbackRoutes);
await app.register(registerOwnerRoutes);
await app.register(registerAdminRoutes);

app.setNotFoundHandler(async (request, reply) => reply.code(404).send({
  error: 'NOT_FOUND',
  requestId: request.id,
}));

app.setErrorHandler(async (error, request, reply) => {
  request.log.error({ err: error, requestId: request.id }, 'Unhandled request error');
  if (reply.sent) return;
  return reply.code(500).send({ error: 'INTERNAL_ERROR', requestId: request.id });
});

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

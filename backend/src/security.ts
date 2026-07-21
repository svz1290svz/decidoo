import type { FastifyInstance } from 'fastify';

const WINDOW_MS = 60_000;
const MAX_REQUESTS = 120;
const AUTH_MAX_REQUESTS = 20;

type Bucket = { count: number; resetAt: number };
const buckets = new Map<string, Bucket>();

const isSensitiveRoute = (url: string): boolean =>
  url.startsWith('/v1/auth/') ||
  url.startsWith('/v1/me') ||
  url.startsWith('/v1/favorites') ||
  url.startsWith('/v1/data-requests') ||
  url.startsWith('/v1/consents');

export const registerSecurity = async (app: FastifyInstance): Promise<void> => {
  app.addHook('onSend', async (request, reply, payload) => {
    reply.header('x-request-id', request.id);
    reply.header('x-content-type-options', 'nosniff');
    reply.header('x-frame-options', 'DENY');
    reply.header('referrer-policy', 'no-referrer');
    reply.header('permissions-policy', 'camera=(), microphone=(), geolocation=(self)');
    reply.header('content-security-policy', "default-src 'none'; frame-ancestors 'none'");
    reply.header('strict-transport-security', 'max-age=31536000; includeSubDomains');
    if (isSensitiveRoute(request.url)) {
      reply.header('cache-control', 'no-store, max-age=0');
      reply.header('pragma', 'no-cache');
    }
    return payload;
  });

  app.addHook('onRequest', async (request, reply) => {
    const now = Date.now();
    const isAuth = request.url.startsWith('/v1/auth/');
    const key = `${request.ip}:${isAuth ? 'auth' : 'api'}`;
    const limit = isAuth ? AUTH_MAX_REQUESTS : MAX_REQUESTS;
    const current = buckets.get(key);
    const bucket = !current || current.resetAt <= now
      ? { count: 0, resetAt: now + WINDOW_MS }
      : current;
    bucket.count += 1;
    buckets.set(key, bucket);

    reply.header('x-ratelimit-limit', limit);
    reply.header('x-ratelimit-remaining', Math.max(0, limit - bucket.count));
    reply.header('x-ratelimit-reset', Math.ceil(bucket.resetAt / 1000));

    if (bucket.count > limit) {
      const retryAfter = Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
      reply.header('retry-after', retryAfter);
      return reply.code(429).send({
        error: 'RATE_LIMITED',
        retryAfterSeconds: retryAfter,
        requestId: request.id,
      });
    }

    if (buckets.size > 10_000) {
      for (const [bucketKey, value] of buckets) {
        if (value.resetAt <= now) buckets.delete(bucketKey);
      }
    }
  });

  app.setErrorHandler((error, request, reply) => {
    request.log.error({ err: error, requestId: request.id }, 'Unhandled request error');

    const statusCode = error.statusCode && error.statusCode >= 400
      ? error.statusCode
      : 500;
    const publicCode = statusCode >= 500 ? 'INTERNAL_ERROR' : 'REQUEST_FAILED';

    return reply.code(statusCode).send({
      error: publicCode,
      requestId: request.id,
    });
  });
};

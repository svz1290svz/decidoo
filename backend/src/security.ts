import type { FastifyInstance } from 'fastify';

const WINDOW_MS = 60_000;
const MAX_REQUESTS = 120;
const AUTH_MAX_REQUESTS = 20;

type Bucket = { count: number; resetAt: number };
const buckets = new Map<string, Bucket>();

export const registerSecurity = async (app: FastifyInstance): Promise<void> => {
  app.addHook('onSend', async (_request, reply, payload) => {
    reply.header('x-content-type-options', 'nosniff');
    reply.header('x-frame-options', 'DENY');
    reply.header('referrer-policy', 'no-referrer');
    reply.header('permissions-policy', 'camera=(), microphone=(), geolocation=(self)');
    reply.header('content-security-policy', "default-src 'none'; frame-ancestors 'none'");
    reply.header('strict-transport-security', 'max-age=31536000; includeSubDomains');
    return payload;
  });

  app.addHook('onRequest', async (request, reply) => {
    const now = Date.now();
    const key = `${request.ip}:${request.url.startsWith('/v1/auth/') ? 'auth' : 'api'}`;
    const limit = request.url.startsWith('/v1/auth/') ? AUTH_MAX_REQUESTS : MAX_REQUESTS;
    const current = buckets.get(key);
    const bucket = !current || current.resetAt <= now ? { count: 0, resetAt: now + WINDOW_MS } : current;
    bucket.count += 1;
    buckets.set(key, bucket);

    reply.header('x-ratelimit-limit', limit);
    reply.header('x-ratelimit-remaining', Math.max(0, limit - bucket.count));
    reply.header('x-ratelimit-reset', Math.ceil(bucket.resetAt / 1000));

    if (bucket.count > limit) {
      reply.header('retry-after', Math.ceil((bucket.resetAt - now) / 1000));
      return reply.code(429).send({ error: 'RATE_LIMITED' });
    }

    if (buckets.size > 10_000) {
      for (const [bucketKey, value] of buckets) {
        if (value.resetAt <= now) buckets.delete(bucketKey);
      }
    }
  });
};

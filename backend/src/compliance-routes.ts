import type { FastifyInstance, FastifyRequest } from 'fastify';
import { verifyAccessToken } from './auth.js';
import { prisma } from './db.js';

type ConsentBody = {
  type?: string;
  granted?: boolean;
  version?: string;
};

type DataRequestBody = {
  type?: string;
  note?: string;
};

const consentTypes = new Set([
  'TERMS_OF_SERVICE',
  'PRIVACY_POLICY',
  'PERSONALIZATION',
  'MARKETING_EMAIL',
  'MARKETING_PUSH',
  'LOCATION_PROCESSING',
]);

const dataRequestTypes = new Set([
  'ACCESS',
  'EXPORT',
  'RECTIFICATION',
  'DELETION',
  'RESTRICTION',
  'OBJECTION',
]);

const userIdFromRequest = (request: FastifyRequest): string => {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    throw new Error('UNAUTHORIZED');
  }

  return verifyAccessToken(header.slice(7)).sub;
};

export const registerComplianceRoutes = async (app: FastifyInstance): Promise<void> => {
  app.get('/v1/consents', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const records = await prisma.consentLog.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
      });

      const latestByType = new Map<string, (typeof records)[number]>();
      for (const record of records) {
        if (!latestByType.has(record.type)) latestByType.set(record.type, record);
      }

      return { consents: [...latestByType.values()] };
    } catch {
      return reply.code(401).send({ error: 'Unauthorized' });
    }
  });

  app.post<{ Body: ConsentBody }>('/v1/consents', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const { type, granted, version } = request.body ?? {};

      if (!type || !consentTypes.has(type) || typeof granted !== 'boolean' || !version?.trim()) {
        return reply.code(400).send({ error: 'Invalid consent payload' });
      }

      const consent = await prisma.consentLog.create({
        data: {
          userId,
          type: type as never,
          granted,
          version: version.trim(),
          ipAddress: request.ip,
        },
      });

      return reply.code(201).send({ consent });
    } catch {
      return reply.code(401).send({ error: 'Unauthorized' });
    }
  });

  app.get('/v1/data-requests', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const requests = await prisma.dataRequest.findMany({
        where: { userId },
        orderBy: { requestedAt: 'desc' },
      });
      return { requests };
    } catch {
      return reply.code(401).send({ error: 'Unauthorized' });
    }
  });

  app.post<{ Body: DataRequestBody }>('/v1/data-requests', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const { type, note } = request.body ?? {};

      if (!type || !dataRequestTypes.has(type)) {
        return reply.code(400).send({ error: 'Invalid data request type' });
      }

      const duplicate = await prisma.dataRequest.findFirst({
        where: {
          userId,
          type: type as never,
          status: { in: ['PENDING', 'IN_REVIEW'] },
        },
      });

      if (duplicate) {
        return reply.code(409).send({
          error: 'An active request of this type already exists',
          requestId: duplicate.id,
        });
      }

      const dataRequest = await prisma.dataRequest.create({
        data: {
          userId,
          type: type as never,
          note: note?.trim() || null,
        },
      });

      return reply.code(201).send({ dataRequest });
    } catch {
      return reply.code(401).send({ error: 'Unauthorized' });
    }
  });
};

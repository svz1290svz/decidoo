import { ConsentType, DataRequestStatus, DataRequestType } from '@prisma/client';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { verifyAccessToken } from './auth.js';
import { prisma } from './db.js';

type ConsentBody = {
  type?: ConsentType;
  granted?: boolean;
  version?: string;
};

type DataRequestBody = {
  type?: DataRequestType;
  note?: string;
};

type DeleteAccountBody = {
  confirmation?: string;
};

const consentTypes = new Set<ConsentType>(Object.values(ConsentType));
const dataRequestTypes = new Set<DataRequestType>(Object.values(DataRequestType));

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

      const latestByType = new Map<ConsentType, (typeof records)[number]>();
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
          type,
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
          type,
          status: { in: [DataRequestStatus.PENDING, DataRequestStatus.IN_REVIEW] },
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
          type,
          note: note?.trim() || null,
        },
      });

      return reply.code(201).send({ dataRequest });
    } catch {
      return reply.code(401).send({ error: 'Unauthorized' });
    }
  });

  app.delete<{ Body: DeleteAccountBody }>('/v1/me/account', async (request, reply) => {
    let userId: string;
    try {
      userId = userIdFromRequest(request);
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }

    if (request.body?.confirmation !== 'DELETE') {
      return reply.code(400).send({ error: 'DELETION_CONFIRMATION_REQUIRED' });
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });
    if (!user) {
      return reply.code(204).send();
    }

    await prisma.$transaction(async (tx) => {
      // PushDevice and AuditEvent intentionally have no FK to User so that
      // notification delivery and immutable audit history cannot block deletion.
      // Remove/anonymize the personal identifier explicitly before deleting User.
      await tx.pushDevice.deleteMany({ where: { userId } });
      await tx.auditEvent.updateMany({
        where: { actorUserId: userId },
        data: { actorUserId: null },
      });

      // User-owned personal rows use ON DELETE CASCADE/SET NULL in Prisma.
      // Business restaurant records remain intact while memberships are removed.
      await tx.user.delete({ where: { id: userId } });
    });

    return reply.code(204).send();
  });
};

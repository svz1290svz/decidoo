import type { FastifyInstance, FastifyRequest } from 'fastify';
import { RestaurantStatus, UserRole } from '@prisma/client';
import { z } from 'zod';
import { verifyAccessToken } from './auth.js';
import { prisma } from './db.js';

const restaurantSchema = z.object({
  name: z.string().trim().min(2).max(120),
  slug: z.string().trim().min(2).max(120).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  description: z.string().trim().max(1000).optional(),
  addressLine: z.string().trim().min(5).max(200),
  district: z.string().trim().max(80).optional(),
  city: z.string().trim().min(2).max(80),
  countryCode: z.string().trim().length(2).transform((value) => value.toUpperCase()).default('TR'),
  latitude: z.coerce.number().min(-90).max(90),
  longitude: z.coerce.number().min(-180).max(180),
  phone: z.string().trim().max(40).optional(),
  email: z.string().email().optional(),
});

const restaurantUpdateSchema = restaurantSchema.partial().omit({ slug: true });
const categorySchema = z.object({ name: z.string().trim().min(1).max(80), sortOrder: z.coerce.number().int().min(0).default(0) });
const mealSchema = z.object({
  categoryId: z.string().cuid().optional(),
  name: z.string().trim().min(2).max(120),
  description: z.string().trim().max(1000).optional(),
  imageUrl: z.string().url().optional(),
  price: z.coerce.number().positive().max(100000),
  currency: z.string().trim().length(3).transform((value) => value.toUpperCase()).default('TRY'),
  cuisine: z.string().trim().max(80).optional(),
  mealType: z.string().trim().max(80).optional(),
  ingredients: z.array(z.string().trim().min(1).max(80)).max(100).default([]),
  allergens: z.array(z.string().trim().min(1).max(80)).max(30).default([]),
  tags: z.array(z.string().trim().min(1).max(50)).max(30).default([]),
  isVegetarian: z.boolean().default(false),
  isVegan: z.boolean().default(false),
  isGlutenFree: z.boolean().default(false),
  isHalal: z.boolean().default(false),
  isAvailable: z.boolean().default(true),
});
const mealUpdateSchema = mealSchema.partial();
const timePattern = /^([01]\d|2[0-3]):[0-5]\d$/;
const operatingHourSchema = z.object({
  dayOfWeek: z.coerce.number().int().min(0).max(6),
  isClosed: z.boolean().default(false),
  opensAt: z.string().regex(timePattern).nullable().optional(),
  closesAt: z.string().regex(timePattern).nullable().optional(),
}).superRefine((value, context) => {
  if (!value.isClosed && (!value.opensAt || !value.closesAt)) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Opening and closing times are required.' });
  }
  if (!value.isClosed && value.opensAt && value.closesAt && value.opensAt === value.closesAt) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Opening and closing times must differ.' });
  }
});
const operatingHoursSchema = z.object({ hours: z.array(operatingHourSchema).min(1).max(7) });

const userIdFromRequest = (request: FastifyRequest): string => {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) throw new Error('UNAUTHORIZED');
  return verifyAccessToken(header.slice(7).trim()).sub;
};

const ownsRestaurant = async (userId: string, restaurantId: string): Promise<boolean> => {
  const membership = await prisma.restaurantMember.findUnique({
    where: { userId_restaurantId: { userId, restaurantId } },
    select: { id: true },
  });
  return Boolean(membership);
};

export const registerOwnerRoutes = async (app: FastifyInstance): Promise<void> => {
  app.get('/v1/owner/restaurants', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const memberships = await prisma.restaurantMember.findMany({
        where: { userId },
        include: { restaurant: { include: { categories: true, meals: true } } },
      });
      const restaurantIds = memberships.map((item) => item.restaurantId);
      const hours = await prisma.restaurantOperatingHour.findMany({
        where: { restaurantId: { in: restaurantIds } },
        orderBy: [{ restaurantId: 'asc' }, { dayOfWeek: 'asc' }],
      });
      return {
        restaurants: memberships.map((item) => ({
          ...item.restaurant,
          operatingHours: hours.filter((hour) => hour.restaurantId === item.restaurantId),
        })),
      };
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.post('/v1/owner/restaurants', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const parsed = restaurantSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });

      const restaurant = await prisma.$transaction(async (tx) => {
        const created = await tx.restaurant.create({
          data: { ...parsed.data, status: RestaurantStatus.PENDING_APPROVAL },
        });
        await tx.restaurantMember.create({
          data: { userId, restaurantId: created.id, permissions: ['OWNER', 'MENU_WRITE', 'CAMPAIGN_WRITE'] },
        });
        await tx.user.update({ where: { id: userId }, data: { role: UserRole.RESTAURANT_OWNER } });
        return created;
      });
      return reply.code(201).send({ restaurant });
    } catch (error) {
      if (error instanceof Error && error.message.includes('Unique constraint')) {
        return reply.code(409).send({ error: 'SLUG_ALREADY_EXISTS' });
      }
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.patch<{ Params: { id: string } }>('/v1/owner/restaurants/:id', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      if (!(await ownsRestaurant(userId, request.params.id))) return reply.code(403).send({ error: 'FORBIDDEN' });
      const parsed = restaurantUpdateSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
      const restaurant = await prisma.restaurant.update({ where: { id: request.params.id }, data: parsed.data });
      return { restaurant };
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.put<{ Params: { id: string } }>('/v1/owner/restaurants/:id/operating-hours', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      if (!(await ownsRestaurant(userId, request.params.id))) return reply.code(403).send({ error: 'FORBIDDEN' });
      const parsed = operatingHoursSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
      const uniqueDays = new Set(parsed.data.hours.map((hour) => hour.dayOfWeek));
      if (uniqueDays.size !== parsed.data.hours.length) return reply.code(400).send({ error: 'DUPLICATE_DAY' });

      await prisma.$transaction(
        parsed.data.hours.map((hour) => prisma.restaurantOperatingHour.upsert({
          where: { restaurantId_dayOfWeek: { restaurantId: request.params.id, dayOfWeek: hour.dayOfWeek } },
          create: {
            restaurantId: request.params.id,
            dayOfWeek: hour.dayOfWeek,
            isClosed: hour.isClosed,
            opensAt: hour.isClosed ? null : hour.opensAt,
            closesAt: hour.isClosed ? null : hour.closesAt,
          },
          update: {
            isClosed: hour.isClosed,
            opensAt: hour.isClosed ? null : hour.opensAt,
            closesAt: hour.isClosed ? null : hour.closesAt,
          },
        })),
      );
      const hours = await prisma.restaurantOperatingHour.findMany({
        where: { restaurantId: request.params.id },
        orderBy: { dayOfWeek: 'asc' },
      });
      return { hours };
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.post<{ Params: { id: string } }>('/v1/owner/restaurants/:id/categories', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      if (!(await ownsRestaurant(userId, request.params.id))) return reply.code(403).send({ error: 'FORBIDDEN' });
      const parsed = categorySchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
      const category = await prisma.menuCategory.create({ data: { restaurantId: request.params.id, ...parsed.data } });
      return reply.code(201).send({ category });
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.post<{ Params: { id: string } }>('/v1/owner/restaurants/:id/meals', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      if (!(await ownsRestaurant(userId, request.params.id))) return reply.code(403).send({ error: 'FORBIDDEN' });
      const parsed = mealSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
      if (parsed.data.categoryId) {
        const category = await prisma.menuCategory.findFirst({ where: { id: parsed.data.categoryId, restaurantId: request.params.id } });
        if (!category) return reply.code(400).send({ error: 'INVALID_CATEGORY' });
      }
      const meal = await prisma.meal.create({ data: { restaurantId: request.params.id, ...parsed.data } });
      return reply.code(201).send({ meal: { ...meal, price: Number(meal.price) } });
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });

  app.patch<{ Params: { id: string } }>('/v1/owner/meals/:id', async (request, reply) => {
    try {
      const userId = userIdFromRequest(request);
      const meal = await prisma.meal.findUnique({ where: { id: request.params.id }, select: { restaurantId: true } });
      if (!meal) return reply.code(404).send({ error: 'MEAL_NOT_FOUND' });
      if (!(await ownsRestaurant(userId, meal.restaurantId))) return reply.code(403).send({ error: 'FORBIDDEN' });
      const parsed = mealUpdateSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'INVALID_INPUT', details: parsed.error.flatten() });
      const updated = await prisma.meal.update({ where: { id: request.params.id }, data: parsed.data });
      return { meal: { ...updated, price: Number(updated.price) } };
    } catch {
      return reply.code(401).send({ error: 'AUTH_REQUIRED' });
    }
  });
};

import { readFile } from 'node:fs/promises';
import process from 'node:process';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const file = process.argv[2];

if (!file) {
  console.error('Usage: node tool/import-restaurants.mjs <catalog.json>');
  process.exit(1);
}

const text = await readFile(file, 'utf8');
const catalog = JSON.parse(text);
if (!Array.isArray(catalog)) throw new Error('Catalog root must be an array');

const nonEmpty = (value, field) => {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`${field} is required`);
  }
  return value.trim();
};

let restaurantCount = 0;
let mealCount = 0;

for (const [index, item] of catalog.entries()) {
  const name = nonEmpty(item.name, `restaurants[${index}].name`);
  const slug = nonEmpty(item.slug, `restaurants[${index}].slug`);
  const city = nonEmpty(item.city, `restaurants[${index}].city`);
  const addressLine = nonEmpty(item.addressLine, `restaurants[${index}].addressLine`);
  const latitude = Number(item.latitude);
  const longitude = Number(item.longitude);
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    throw new Error(`restaurants[${index}].latitude is invalid`);
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new Error(`restaurants[${index}].longitude is invalid`);
  }

  await prisma.$transaction(async (tx) => {
    const restaurant = await tx.restaurant.upsert({
      where: { slug },
      update: {
        name,
        description: item.description ?? null,
        logoUrl: item.logoUrl ?? null,
        coverUrl: item.coverUrl ?? null,
        phone: item.phone ?? null,
        email: item.email ?? null,
        addressLine,
        district: item.district ?? null,
        city,
        countryCode: item.countryCode ?? 'TR',
        latitude,
        longitude,
        currency: item.currency ?? 'TRY',
        status: item.status ?? 'PENDING_APPROVAL',
      },
      create: {
        name,
        slug,
        description: item.description ?? null,
        logoUrl: item.logoUrl ?? null,
        coverUrl: item.coverUrl ?? null,
        phone: item.phone ?? null,
        email: item.email ?? null,
        addressLine,
        district: item.district ?? null,
        city,
        countryCode: item.countryCode ?? 'TR',
        latitude,
        longitude,
        currency: item.currency ?? 'TRY',
        status: item.status ?? 'PENDING_APPROVAL',
      },
    });

    for (const [categoryIndex, categoryInput] of (item.categories ?? []).entries()) {
      const categoryName = nonEmpty(
        categoryInput.name,
        `restaurants[${index}].categories[${categoryIndex}].name`,
      );
      let category = await tx.menuCategory.findFirst({
        where: { restaurantId: restaurant.id, name: categoryName },
      });
      category ??= await tx.menuCategory.create({
        data: {
          restaurantId: restaurant.id,
          name: categoryName,
          sortOrder: Number(categoryInput.sortOrder ?? categoryIndex),
        },
      });

      for (const [mealIndex, mealInput] of (categoryInput.meals ?? []).entries()) {
        const mealName = nonEmpty(
          mealInput.name,
          `restaurants[${index}].categories[${categoryIndex}].meals[${mealIndex}].name`,
        );
        const price = Number(mealInput.price);
        if (!Number.isFinite(price) || price <= 0) {
          throw new Error(`${mealName} price is invalid`);
        }
        const existing = await tx.meal.findFirst({
          where: { restaurantId: restaurant.id, categoryId: category.id, name: mealName },
        });
        const data = {
          categoryId: category.id,
          name: mealName,
          description: mealInput.description ?? null,
          imageUrl: mealInput.imageUrl ?? null,
          price,
          currency: mealInput.currency ?? item.currency ?? 'TRY',
          cuisine: mealInput.cuisine ?? null,
          mealType: mealInput.mealType ?? null,
          ingredients: mealInput.ingredients ?? [],
          allergens: mealInput.allergens ?? [],
          tags: mealInput.tags ?? [],
          isVegetarian: Boolean(mealInput.isVegetarian),
          isVegan: Boolean(mealInput.isVegan),
          isGlutenFree: Boolean(mealInput.isGlutenFree),
          isHalal: Boolean(mealInput.isHalal),
          isAvailable: mealInput.isAvailable !== false,
        };
        if (existing) {
          await tx.meal.update({ where: { id: existing.id }, data });
        } else {
          await tx.meal.create({ data: { restaurantId: restaurant.id, ...data } });
        }
        mealCount += 1;
      }
    }
    restaurantCount += 1;
  });
}

console.log(JSON.stringify({ importedRestaurants: restaurantCount, importedMeals: mealCount }));
await prisma.$disconnect();

import 'dotenv/config';
import bcrypt from 'bcryptjs';
import { PrismaClient, RestaurantStatus, UserRole } from '@prisma/client';

const prisma = new PrismaClient();

const restaurants = [
  {
    slug: 'anadolu-sofrasi-eskisehir',
    name: 'Anadolu Sofrası',
    description: 'Geleneksel Türk mutfağından günlük hazırlanan yemekler.',
    addressLine: 'Hoşnudiye Mahallesi',
    district: 'Tepebaşı',
    city: 'Eskişehir',
    latitude: 39.7767,
    longitude: 30.5206,
    averageRating: 4.7,
    reviewCount: 184,
    meals: [
      { name: 'Eskişehir Çiböreği', price: 220, cuisine: 'Türk', tags: ['yerel', 'popüler'], isHalal: true },
      { name: 'Etli Güveç', price: 390, cuisine: 'Türk', tags: ['ev yemeği'], isHalal: true },
    ],
  },
  {
    slug: 'yesil-tabak-eskisehir',
    name: 'Yeşil Tabak',
    description: 'Taze, dengeli ve bitki ağırlıklı seçenekler.',
    addressLine: 'Vişnelik Mahallesi',
    district: 'Odunpazarı',
    city: 'Eskişehir',
    latitude: 39.7662,
    longitude: 30.5108,
    averageRating: 4.6,
    reviewCount: 96,
    meals: [
      { name: 'Vegan Bowl', price: 310, cuisine: 'Sağlıklı', tags: ['vegan', 'glutensiz'], isVegetarian: true, isVegan: true, isGlutenFree: true },
      { name: 'Izgara Hellim Salata', price: 285, cuisine: 'Akdeniz', tags: ['vejetaryen'], isVegetarian: true },
    ],
  },
  {
    slug: 'ates-burger-eskisehir',
    name: 'Ateş Burger',
    description: 'El yapımı ekmek ve günlük hazırlanan burgerler.',
    addressLine: 'İsmet İnönü Caddesi',
    district: 'Tepebaşı',
    city: 'Eskişehir',
    latitude: 39.7811,
    longitude: 30.5149,
    averageRating: 4.5,
    reviewCount: 241,
    meals: [
      { name: 'Decidoo Burger', price: 345, cuisine: 'Burger', tags: ['popüler'], isHalal: true },
      { name: 'Çıtır Tavuk Burger', price: 315, cuisine: 'Burger', tags: ['tavuk'], isHalal: true },
    ],
  },
];

async function seedAdmin() {
  const email = process.env.SEED_ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.SEED_ADMIN_PASSWORD;
  if (!email || !password) return;
  if (password.length < 12) throw new Error('SEED_ADMIN_PASSWORD must be at least 12 characters');

  await prisma.user.upsert({
    where: { email },
    update: { role: UserRole.ADMIN, status: 'ACTIVE' },
    create: {
      email,
      passwordHash: await bcrypt.hash(password, 12),
      displayName: 'Decidoo Admin',
      role: UserRole.ADMIN,
      onboardingDone: true,
    },
  });
}

async function seedRestaurants() {
  for (const item of restaurants) {
    const { meals, ...restaurantData } = item;
    const restaurant = await prisma.restaurant.upsert({
      where: { slug: item.slug },
      update: { ...restaurantData, status: RestaurantStatus.ACTIVE, isVerified: true, isOpen: true },
      create: { ...restaurantData, status: RestaurantStatus.ACTIVE, isVerified: true, isOpen: true },
    });

    const category = await prisma.menuCategory.upsert({
      where: { id: `seed-${item.slug}` },
      update: { name: 'Öne Çıkanlar', restaurantId: restaurant.id, isActive: true },
      create: { id: `seed-${item.slug}`, name: 'Öne Çıkanlar', restaurantId: restaurant.id, isActive: true },
    });

    for (const meal of meals) {
      const existing = await prisma.meal.findFirst({ where: { restaurantId: restaurant.id, name: meal.name } });
      const data = {
        ...meal,
        restaurantId: restaurant.id,
        categoryId: category.id,
        currency: 'TRY',
        ingredients: [],
        allergens: [],
        isAvailable: true,
      };
      if (existing) await prisma.meal.update({ where: { id: existing.id }, data });
      else await prisma.meal.create({ data });
    }
  }
}

try {
  await seedAdmin();
  await seedRestaurants();
  console.log('Decidoo seed completed.');
} finally {
  await prisma.$disconnect();
}

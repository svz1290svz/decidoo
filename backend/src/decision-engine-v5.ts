export type OperatingHour = {
  dayOfWeek: number;
  opensAt: string | null;
  closesAt: string | null;
  isClosed: boolean;
};

export type ContextMeal = {
  mealType: string | null;
  tags: string[];
  calories: number | null;
  preparationMin: number | null;
  updatedAt: Date;
};

const minutes = (value: string): number => {
  const [hour = 0, minute = 0] = value.split(':').map(Number);
  return hour * 60 + minute;
};

const zonedParts = (
  date: Date,
  timeZone: string,
): { day: number; minuteOfDay: number } => {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const weekday =
    parts.find((part) => part.type === 'weekday')?.value ?? 'Sun';
  const hour = Number(parts.find((part) => part.type === 'hour')?.value ?? 0);
  const minute = Number(
    parts.find((part) => part.type === 'minute')?.value ?? 0,
  );
  const day = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(
    weekday,
  );
  return { day: day < 0 ? 0 : day, minuteOfDay: hour * 60 + minute };
};

export const isOpenAt = (
  hours: OperatingHour[],
  now: Date,
  timeZone: string,
): boolean => {
  if (hours.length === 0) return true;
  const local = zonedParts(now, timeZone);
  const today = hours.find((hour) => hour.dayOfWeek === local.day);
  const yesterday = hours.find(
    (hour) => hour.dayOfWeek === (local.day + 6) % 7,
  );

  if (
    yesterday &&
    !yesterday.isClosed &&
    yesterday.opensAt &&
    yesterday.closesAt
  ) {
    const open = minutes(yesterday.opensAt);
    const close = minutes(yesterday.closesAt);
    if (close < open && local.minuteOfDay < close) return true;
  }

  if (!today || today.isClosed || !today.opensAt || !today.closesAt) {
    return false;
  }
  const open = minutes(today.opensAt);
  const close = minutes(today.closesAt);
  return close > open
    ? local.minuteOfDay >= open && local.minuteOfDay < close
    : local.minuteOfDay >= open;
};

const includesAny = (tags: string[], values: string[]): boolean => {
  const normalized = tags.map((tag) => tag.trim().toLowerCase());
  return values.some((value) =>
    normalized.some((tag) => tag.includes(value)),
  );
};

export const contextScoreV5 = (
  meal: ContextMeal,
  context: { mood?: string; hungerLevel?: number; mealType?: string },
): { score: number; reasons: string[] } => {
  let score = 0;
  const reasons: string[] = [];
  const mood = context.mood?.trim().toLowerCase() ?? '';
  const hunger = context.hungerLevel ?? 3;

  if (hunger >= 4) {
    if (
      (meal.calories ?? 0) >= 550 ||
      includesAny(meal.tags, ['hearty', 'filling', 'protein', 'grill'])
    ) {
      score += 0.45;
      reasons.push('HUNGER_FIT');
    }
    if ((meal.preparationMin ?? 99) <= 20) score += 0.12;
  } else if (hunger <= 2) {
    if (
      (meal.calories ?? 9999) <= 500 ||
      includesAny(meal.tags, ['light', 'salad', 'soup', 'healthy'])
    ) {
      score += 0.4;
      reasons.push('LIGHT_FIT');
    }
  }

  if (mood) {
    const comfort = [
      'comfort',
      'cozy',
      'indulgent',
      'dessert',
      'pizza',
      'burger',
    ];
    const fresh = ['fresh', 'healthy', 'salad', 'bowl', 'vegetable'];
    if (
      ['sad', 'stressed', 'tired', 'comfort'].some((key) =>
        mood.includes(key),
      ) && includesAny(meal.tags, comfort)
    ) {
      score += 0.3;
      reasons.push('MOOD_FIT');
    }
    if (
      ['fresh', 'healthy', 'energetic', 'light'].some((key) =>
        mood.includes(key),
      ) && includesAny(meal.tags, fresh)
    ) {
      score += 0.3;
      reasons.push('MOOD_FIT');
    }
  }

  if (
    context.mealType &&
    meal.mealType?.toLowerCase() === context.mealType.toLowerCase()
  ) {
    score += 0.2;
  }
  return { score, reasons };
};

export const freshnessScoreV5 = (
  updatedAt: Date,
  now: Date,
): { score: number; stale: boolean } => {
  const ageDays = Math.max(
    0,
    (now.getTime() - updatedAt.getTime()) / 86_400_000,
  );
  if (ageDays <= 7) return { score: 0.25, stale: false };
  if (ageDays <= 30) return { score: 0.12, stale: false };
  if (ageDays <= 90) return { score: 0, stale: false };
  return { score: -0.35, stale: true };
};

export const diversifyV5 = <
  T extends {
    restaurant: { id: string };
    meal: { cuisine: string | null };
    score: number;
  },
>(
  ranked: T[],
  limit: number,
): T[] => {
  const selected: T[] = [];
  const restaurantCounts = new Map<string, number>();
  const cuisineCounts = new Map<string, number>();
  const pool = ranked.slice();

  while (pool.length > 0 && selected.length < limit) {
    let bestIndex = -1;
    let bestAdjusted = -Infinity;
    pool.forEach((item, index) => {
      const restaurantCount = restaurantCounts.get(item.restaurant.id) ?? 0;
      if (restaurantCount >= 2) return;
      const cuisine = item.meal.cuisine?.toLowerCase() ?? '';
      const cuisinePenalty = (cuisineCounts.get(cuisine) ?? 0) * 0.18;
      const adjusted =
        item.score - cuisinePenalty - restaurantCount * 0.28;
      if (adjusted > bestAdjusted) {
        bestAdjusted = adjusted;
        bestIndex = index;
      }
    });
    if (bestIndex < 0) break;
    const chosen = pool.splice(bestIndex, 1)[0];
    if (!chosen) break;
    selected.push(chosen);
    restaurantCounts.set(
      chosen.restaurant.id,
      (restaurantCounts.get(chosen.restaurant.id) ?? 0) + 1,
    );
    const cuisine = chosen.meal.cuisine?.toLowerCase() ?? '';
    cuisineCounts.set(cuisine, (cuisineCounts.get(cuisine) ?? 0) + 1);
  }
  return selected;
};

export const confidenceV5 = (scores: number[]): number => {
  if (scores.length === 0) return 0;
  if (scores.length === 1) return 0.72;
  const first = scores[0];
  const second = scores[1];
  if (first === undefined || second === undefined) return 0.72;
  const gap = Math.max(0, first - second);
  return Math.min(
    0.98,
    Math.max(0.35, 0.55 + gap / 4 + Math.min(first, 6) / 30),
  );
};

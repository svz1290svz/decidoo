export type WeatherContextV6 = {
  condition?: string;
  temperatureC?: number;
  precipitationProbability?: number;
};

export type DecisionCandidateV6 = {
  score: number;
  reasons: string[];
  meal: {
    id: string;
    name: string;
    cuisine: string | null;
    mealType: string | null;
    tags: string[];
  };
  restaurant: {
    id: string;
    name: string;
  };
};

const normalize = (value: string | undefined): string => value?.trim().toLowerCase() ?? '';

const includesAny = (tags: string[], values: string[]): boolean => {
  const normalized = tags.map((tag) => tag.trim().toLowerCase());
  return values.some((value) => normalized.some((tag) => tag.includes(value)));
};

export const weatherScoreV6 = (
  tags: string[],
  weather?: WeatherContextV6,
): { score: number; reasons: string[] } => {
  if (!weather) return { score: 0, reasons: [] };
  let score = 0;
  const reasons: string[] = [];
  const condition = normalize(weather.condition);
  const temperature = weather.temperatureC;
  const precipitation = weather.precipitationProbability ?? 0;

  const coldOrWet =
    (temperature !== undefined && temperature <= 12) ||
    precipitation >= 0.5 ||
    ['rain', 'snow', 'storm', 'drizzle'].some((key) => condition.includes(key));
  if (coldOrWet && includesAny(tags, ['soup', 'hot', 'warm', 'comfort', 'stew', 'ramen'])) {
    score += 0.35;
    reasons.push('WEATHER_COMFORT_FIT');
  }

  const hot =
    (temperature !== undefined && temperature >= 27) ||
    ['hot', 'sunny', 'clear'].some((key) => condition.includes(key));
  if (hot && includesAny(tags, ['cold', 'fresh', 'salad', 'light', 'bowl', 'fruit'])) {
    score += 0.28;
    reasons.push('WEATHER_FRESH_FIT');
  }

  return { score, reasons };
};

export const decideV6 = <T extends DecisionCandidateV6>(
  candidates: T[],
  weather?: WeatherContextV6,
): { primary: T | null; alternatives: T[]; confidence: number } => {
  const ranked = candidates
    .map((candidate) => {
      const weatherFit = weatherScoreV6(candidate.meal.tags, weather);
      return {
        candidate: {
          ...candidate,
          score: candidate.score + weatherFit.score,
          reasons: [...candidate.reasons, ...weatherFit.reasons],
        } as T,
      };
    })
    .sort((a, b) => b.candidate.score - a.candidate.score)
    .map((entry) => entry.candidate);

  const primary = ranked[0] ?? null;
  if (!primary) return { primary: null, alternatives: [], confidence: 0 };
  const second = ranked[1];
  const gap = second ? Math.max(0, primary.score - second.score) : 1;
  const confidence = Math.min(0.98, Math.max(0.55, 0.68 + gap / 4));
  return { primary, alternatives: ranked.slice(1, 3), confidence };
};

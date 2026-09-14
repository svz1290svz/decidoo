import { env } from './config.js';
import type { WeatherContextV6 } from './decision-engine-v6.js';

type FetchLike = typeof fetch;

type OpenMeteoCurrent = {
  temperature_2m?: unknown;
  weather_code?: unknown;
};

const conditionForCode = (code: number): string => {
  if (code === 0) return 'Clear';
  if (code <= 3) return 'Cloudy';
  if (code === 45 || code === 48) return 'Fog';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code >= 61 && code <= 67) return 'Rain';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Rain showers';
  if (code >= 85 && code <= 86) return 'Snow showers';
  if (code >= 95) return 'Storm';
  return 'Unknown';
};

export type ResolvedWeatherV7 = {
  weather: WeatherContextV6;
  source: 'open-meteo';
};

export const fetchWeatherV7 = async (
  latitude: number,
  longitude: number,
  fetcher: FetchLike = fetch,
): Promise<ResolvedWeatherV7> => {
  const url = new URL(env.WEATHER_API_BASE_URL);
  url.searchParams.set('latitude', String(latitude));
  url.searchParams.set('longitude', String(longitude));
  url.searchParams.set('current', 'temperature_2m,weather_code');
  url.searchParams.set('timezone', 'auto');

  const response = await fetcher(url, {
    headers: { accept: 'application/json', 'user-agent': 'decidoo-backend/1.0' },
    signal: AbortSignal.timeout(env.WEATHER_API_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`WEATHER_PROVIDER_${response.status}`);

  const payload = (await response.json()) as { current?: OpenMeteoCurrent };
  const temperature = Number(payload.current?.temperature_2m);
  const weatherCode = Number(payload.current?.weather_code);
  if (!Number.isFinite(temperature) || !Number.isFinite(weatherCode)) {
    throw new Error('WEATHER_PROVIDER_INVALID_RESPONSE');
  }

  return {
    weather: {
      temperatureC: temperature,
      condition: conditionForCode(weatherCode),
    },
    source: 'open-meteo',
  };
};

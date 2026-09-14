import assert from 'node:assert/strict';
import test from 'node:test';
import { fetchWeatherV7 } from './weather-service.js';

test('fetchWeatherV7 converts provider data into decision weather', async () => {
  const fetcher: typeof fetch = async (input) => {
    const url = new URL(String(input));
    assert.equal(url.searchParams.get('latitude'), '39.7767');
    assert.equal(url.searchParams.get('longitude'), '30.5206');
    return new Response(JSON.stringify({ current: { temperature_2m: 8, weather_code: 0 } }));
  };

  const result = await fetchWeatherV7(39.7767, 30.5206, fetcher);
  assert.deepEqual(result, {
    weather: { temperatureC: 8, condition: 'Clear' },
    source: 'open-meteo',
  });
});

test('fetchWeatherV7 rejects incomplete provider responses', async () => {
  const fetcher: typeof fetch = async () => new Response(JSON.stringify({ current: {} }));
  await assert.rejects(() => fetchWeatherV7(1, 1, fetcher), /INVALID_RESPONSE/);
});

test('fetchWeatherV7 rejects provider errors', async () => {
  const fetcher: typeof fetch = async () => new Response('unavailable', { status: 503 });
  await assert.rejects(() => fetchWeatherV7(1, 1, fetcher), /WEATHER_PROVIDER_503/);
});

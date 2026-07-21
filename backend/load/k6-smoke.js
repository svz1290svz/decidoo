import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    steady_read: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      preAllocatedVUs: 50,
      maxVUs: 500,
      stages: [
        { target: 50, duration: '1m' },
        { target: 200, duration: '3m' },
        { target: 0, duration: '30s' },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500', 'p(99)<1200'],
  },
};

const baseUrl = __ENV.BASE_URL;
const accessToken = __ENV.ACCESS_TOKEN;

export default function () {
  const headers = accessToken
    ? { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' }
    : { 'Content-Type': 'application/json' };

  const health = http.get(`${baseUrl}/health`);
  check(health, { 'health is 200': (response) => response.status === 200 });

  const recommendations = http.post(
    `${baseUrl}/v1/recommendations`,
    JSON.stringify({ city: 'Istanbul', limit: 10 }),
    { headers },
  );
  check(recommendations, {
    'recommendations succeeds': (response) => response.status === 200,
    'recommendations has results': (response) => {
      try {
        return Array.isArray(response.json('results'));
      } catch (_) {
        return false;
      }
    },
  });

  sleep(0.2);
}

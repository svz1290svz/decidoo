import { decideV6, type DecisionCandidateV6, type WeatherContextV6 } from './decision-engine-v6.js';

export type DecisionContextV7 = {
  weather?: WeatherContextV6;
  weatherSource: 'client' | 'open-meteo' | null;
  timeContextResolved: boolean;
  personalized: boolean;
};

export const decideV7 = <T extends DecisionCandidateV6>(
  candidates: T[],
  context: DecisionContextV7,
): { primary: T | null; alternatives: T[]; confidence: number; signals: string[] } => {
  const decision = decideV6(candidates, context.weather);
  if (!decision.primary) return { ...decision, signals: [] };

  const signals = [
    context.weatherSource === 'open-meteo' ? 'AUTOMATIC_WEATHER' : null,
    context.weatherSource === 'client' ? 'CLIENT_WEATHER' : null,
    context.timeContextResolved ? 'LOCAL_TIME' : null,
    context.personalized ? 'PERSONALIZATION' : null,
  ].filter((value): value is string => value !== null);

  // Confidence grows only when independent context signals support the ranked
  // result. It remains capped and never fabricates certainty from a single cue.
  const contextBonus = Math.min(signals.length * 0.025, 0.075);
  return {
    ...decision,
    confidence: Math.min(0.98, decision.confidence + contextBonus),
    signals,
  };
};

# Decidoo

Decidoo is a decision engine that removes the friction from choosing what to eat. The product does not return an endless list: it produces one explainable, personalized decision.

## Current product

- Premium mobile-first Flutter experience
- Goal, budget and meal-time personalization
- Explainable weighted recommendation scoring
- Recent-choice diversity to reduce repetition
- Favorites, discovery and decision history
- Global starter food catalog
- Deterministic unit tests for the decision engine
- Modular domain, data, service and presentation layers

## Run

```bash
flutter pub get
flutter test
flutter run
```

## Architecture

```text
lib/
  main.dart
  src/
    app.dart                 # presentation and navigation
    data/food_catalog.dart   # replaceable local data source
    domain/food.dart         # core product models
    services/decision_engine.dart
```

The recommendation engine is deliberately independent from Flutter. It can later be moved behind an API or combined with a remote ML ranking service without rewriting the interface.

## Scale roadmap

### Phase 1 — Product validation

- Authentication and anonymous sessions
- Dietary restrictions and allergy controls
- Location permission and nearby restaurant inventory
- Analytics events, crash reporting and feature flags
- Persistent favorites and decision history

### Phase 2 — Marketplace intelligence

- Restaurant and menu ingestion
- Distance, availability, delivery time and live price signals
- Sponsored recommendations with explicit labeling
- Restaurant dashboard and campaign attribution
- Multilingual catalog and regional ranking models

### Phase 3 — Global platform

- API gateway, rate limiting and regional deployment
- Event pipeline and recommendation feedback loop
- Experimentation platform and model monitoring
- Privacy, consent, deletion and data portability workflows
- Abuse prevention, observability and disaster recovery

## Product principle

Decidoo should optimize for trusted decisions, not maximum scrolling. Recommendation quality, user control and transparent commercial placement are core requirements.

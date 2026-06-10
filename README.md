# Fernecito - Users App

Main user-facing app for Fernecito, an event discovery and nightlife platform.

Live PWA: [appusuarios.fernecitoapp.com](https://appusuarios.fernecitoapp.com)

## What It Does

Fernecito Users App helps people discover what is happening in their city and move from interest to action.

Core flows:

- Explore events, venues, promotions and nightlife plans.
- View event details with images, location, schedule and local context.
- Reserve or confirm attendance through controlled app flows.
- Build and join squads for social plans.
- Use QR-based flows for attendance, invitations and validations.
- Manage user profile, social discovery and account state.

## Product Scope

This repository represents the public frontend implementation of the user app. It is part of a larger product system:

- Users App: this repository.
- Locales App: venue and staff workflows.
- Owner Manager: internal/admin platform operations.
- Backend: private Supabase project with Edge Functions and database logic.

## Stack

- Flutter / Dart
- Flutter Web as PWA
- Supabase Auth, Database, Storage and Realtime
- Supabase Edge Functions integration
- Vercel deployment
- Deep linking and share flows

## Security Notes

This is a public portfolio repository. Production backend code, private database migrations and secrets are intentionally not exposed here.

Frontend builds use compile-time configuration through `--dart-define`. Local `.env` files are ignored and must not be published as web assets.

## Run Locally

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=URL_SUPABASE="your-url" \
  --dart-define=CLAVE_PUBLICA_SUPABASE="your-anon-key"
```

## Production Build

```bash
./deploy.sh
```

The deploy script builds the Flutter web app, prepares Vercel routing and deploys to production.

## Why It Matters

This project shows product engineering work across UX, frontend architecture, authentication, realtime data, mobile-first PWA behavior and production deployment.

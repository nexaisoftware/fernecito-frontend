# Fernecito - Users App

Main user-facing app for Fernecito, an event discovery and nightlife platform.

[![Google Play](https://img.shields.io/badge/Google_Play-Download-414141?logo=googleplay&logoColor=white)](https://play.google.com/store/apps/details?id=com.nexaisoftware.fernecitoapp)
[![App Store](https://img.shields.io/badge/App_Store-Download-0D96F6?logo=appstore&logoColor=white)](APP_STORE_URL)
[![PWA](https://img.shields.io/badge/PWA-Live-5A0FC8?logo=pwa&logoColor=white)](https://appusuarios.fernecitoapp.com)

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3FCF8E?logo=supabase&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-iOS%20%C2%B7%20Android%20%C2%B7%20Web-informational)

> **Shipped in production** on the App Store, Google Play and as a live PWA — three targets from a single Flutter codebase.

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

## Engineering Highlights

- **One auth, three products.** A single Supabase Auth identity works across the Users, Locales and Owner apps; the active context is resolved by which profile the account owns — no duplicated login stacks.
- **Security-first data layer.** Postgres Row Level Security is the backbone; recursive-policy pitfalls are solved with `SECURITY DEFINER` helper functions so venues can read exactly what they need and nothing more.
- **Sensitive logic on the edge.** Reservations, redemptions and account actions run in Deno Edge Functions with the service role, guarded by server-side rate limiting and idempotent flows (double taps never double-charge).
- **Concurrency that holds up at the door.** Limited-capacity guest lists use a compare-and-swap pattern so two people can't take the last slot.
- **QR attendance & promos.** Safe-alphabet door codes with anti-brute-force controls, validated in real time by venue staff.
- **Cross-platform push.** Geo-segmented, deduplicated notifications delivered across iOS, Android and web.

## Why It Matters

This project shows end-to-end product engineering: UX, frontend architecture, authentication, realtime data, mobile-first PWA behavior, and shipping the same codebase to two app stores plus the web.

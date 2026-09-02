# Holo — Frontend

Flutter web and mobile client for Holo, a dating-safety application that scores a
conversation for signs of disengagement.

## Running locally

```bash
cp .env.example .env    # then fill in the values
flutter pub get
flutter run -d chrome
```

## Configuration

`.env` is bundled as a Flutter asset and must contain only publishable keys. It is
not committed; Vercel writes it at build time from the project's environment
variables.

| Variable | Purpose |
|---|---|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Publishable anon key, restricted by row-level security |
| `BACKEND_URL` | Base URL of the analysis API |

## Deployment

Vercel builds this repository with `vercel-build.sh`, which installs the Flutter
SDK, writes `.env` from the configured environment variables, and runs
`flutter build web --release`. Build output is served from `build/web` and is not
committed.

The backend is deployed separately.

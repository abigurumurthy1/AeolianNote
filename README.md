# Aeolian Note

A digital "message in a bottle" iOS app where users launch notes that drift across the US based on real-time wind data.

## Features

- **Launch Notes**: Write 140-character messages and release them into the wind
- **Wind-Driven Drift**: Notes move at 15% of real wind speed, updated every 15 minutes
- **Proximity Discovery**: Catch notes when they drift within 10 miles of your location
- **Journey Tracking**: Watch notes travel across the country on an interactive map
- **Anonymous or Identified**: Choose to reveal your identity or remain anonymous
- **72-Hour Lifespan**: Notes dissolve if uncaught or if they drift to uninhabited areas

## Tech Stack

### iOS App
- Swift/SwiftUI
- MapKit
- CoreLocation
- CoreHaptics

### Backend
- Supabase (PostgreSQL + PostGIS)
- Supabase Edge Functions
- Supabase Realtime

### External APIs
- OpenWeatherMap (wind data)
- OpenAI Moderation API

## Setup

### Prerequisites

- Xcode 15+
- iOS 16+
- Supabase account
- OpenWeatherMap API key
- OpenAI API key

### iOS App

1. Clone the repository
2. Open `AeolianNote.xcodeproj` in Xcode
3. Add the Supabase Swift package dependency
4. Set environment variables in your scheme:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `OPENWEATHERMAP_API_KEY`
   - `OPENAI_API_KEY`
5. Build and run

### Supabase Backend

1. Create a new Supabase project
2. Enable the PostGIS extension in your database
3. Run the migrations in order:
   ```bash
   cd supabase
   supabase db reset
   ```
4. Deploy the wind-engine Edge Function:
   ```bash
   supabase functions deploy wind-engine
   ```
5. Seed the ZIP code data:
   ```bash
   npm install
   npm run seed:zipcodes
   ```
6. Set up pg_cron for automated wind updates (requires Supabase Pro)

## Project Structure

```
AeolianNote/
├── App/                    # Entry point, AppDelegate, Environment
├── Models/                 # Data models (User, Note, WindData, ZipCode)
├── Views/
│   ├── Map/               # WindMapView, NoteAnnotationView
│   ├── Compose/           # ComposeNoteView, LaunchingAnimationView
│   ├── Inbox/             # InboxView, NoteRevealView
│   └── Profile/           # ProfileView
├── ViewModels/            # State management
├── Services/
│   ├── SupabaseClient     # Backend connection
│   ├── WeatherService     # OpenWeatherMap integration
│   ├── LocationService    # CoreLocation
│   ├── ModerationService  # OpenAI content moderation
│   └── PushNotificationService
├── Components/            # Reusable UI components
├── Resources/             # Assets, sounds, fonts
└── supabase/
    ├── migrations/        # Database schema
    ├── functions/         # Edge functions
    └── scripts/           # Seed scripts
```

## Wind Engine Algorithm

The Wind Engine runs every 15 minutes and:

1. Fetches all active notes
2. Groups them by 1-degree grid cells
3. Gets wind data for each region (cached for 30 min)
4. Calculates new positions using Haversine forward projection
5. Checks if notes drifted to uninhabited areas (dissolves them)
6. Detects proximity events (notes within 10 mi of users)
7. Sends push notifications via APNs

### Position Calculation

```
distance = wind_speed_mph × 0.15 × 0.25 hours
new_lat = asin(sin(lat) × cos(d/R) + cos(lat) × sin(d/R) × cos(bearing))
new_lon = lon + atan2(sin(bearing) × sin(d/R) × cos(lat), cos(d/R) - sin(lat) × sin(new_lat))
```

## Database Schema

- **users**: User profiles, locations, stats
- **notes**: Note content, positions, journey paths
- **zip_codes**: US ZIP code reference data (~41K records)
- **wind_cache**: Cached wind data by region
- **note_encounters**: Proximity detection records

## API Keys

### OpenWeatherMap
- Sign up at https://openweathermap.org/api
- Free tier: 1,000 calls/day

### OpenAI
- Sign up at https://platform.openai.com
- Moderation API is free

### Supabase
- Sign up at https://supabase.com
- Free tier available, Pro recommended for pg_cron

## Estimated Costs

| Service | Cost |
|---------|------|
| Supabase Pro | $25/mo |
| OpenWeatherMap | Free |
| OpenAI Moderation | ~$5/mo |
| Apple Developer | $99/yr |
| **Total** | **~$38/mo** |

## License

MIT

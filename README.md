# loscheck

Los Check is a Flutter demo app for tracking delivery trip fees and customer
phone/address records.

## Supabase setup

The app works with local browser storage by default. To also save new records to
Supabase:

1. Create a Supabase project.
2. Open the Supabase SQL Editor and run `supabase/schema.sql`.
3. Run the app with your project URL and publishable key:

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5330 `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Without those two `--dart-define` values, Supabase sync is disabled and local
storage still works.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# Los Check

Flutter web app for tracking delivery trip fees and customer phone/address
records. Deployed on [Vercel](https://los-check.vercel.app).

## Features

- **Trip fee tracking** — select a distance range, enter rounds, and the app
  calculates the fee automatically.
- **Daily / weekly / monthly summaries** — see aggregated totals at a glance.
- **Customer records** — save phone, name, and address. Filter by phone number.
- **Edit & delete with confirmation** — edit trip rounds or customer info;
  delete actions require confirmation.
- **CSV export** — copy all trip or customer data as CSV to the clipboard.
- **Supabase sync (optional)** — two-way sync: push new records to Supabase,
  pull from Supabase, and sync deletes. Works offline with local storage only
  when Supabase is not configured.
- **CI** — GitHub Actions runs `flutter analyze` + `flutter test` on every
  push/PR.

## Architecture

```
lib/
  config/
    supabase_config.dart       # compile-time Supabase credentials
  models/
    customer_record.dart       # customer data model
    distance_option.dart       # distance ↔ rate mapping
    trip_record.dart           # trip data model
  screens/
    customer_page.dart         # customer CRUD + search UI
    trip_fee_page.dart         # trip fee entry + summaries UI
  services/
    csv_export_service.dart    # CSV string generation
    supabase_sync_service.dart # Supabase CRUD (insert/fetch/delete)
  widgets/
    confirm_delete_dialog.dart # shared delete confirmation dialog
    rounds_dialog.dart         # rounds input dialog (add / edit)
  main.dart                   # app entry point + tab shell
```

Data is persisted locally via `shared_preferences`. When Supabase credentials
are provided at build time, records are also synced to Supabase.

## Getting started

```bash
flutter pub get
flutter run -d chrome
```

## Supabase setup

The app works with local browser storage by default. To enable Supabase sync:

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

## Testing

```bash
flutter test
flutter analyze
```

## License

[MIT](LICENSE)

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
  widgets/
    confirm_delete_dialog.dart # shared delete confirmation dialog
    rounds_dialog.dart         # rounds input dialog (add / edit)
  main.dart                   # app entry point + tab shell
```

Data is persisted locally via Isar (NoSQL).

## Getting started

```bash
flutter pub get
flutter run -d chrome
```

> **Web build (Isar):** Isar works on the web using IndexedDB. No extra setup for sql.js is required.


## Testing

```bash
flutter test
flutter analyze
```

## License

[MIT](LICENSE)

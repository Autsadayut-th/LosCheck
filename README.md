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

Data is persisted locally via Drift (SQLite).

## Getting started

```bash
flutter pub get
flutter run -d chrome
```

> **Web build (sql.js):** Drift needs `drift_flutter` to run in the browser.
> The web build loads `sql.js` (SQLite compiled to WebAssembly) from a CDN
> via the `<script>` tag in `web/index.html`. If you ever see the error
> `Unsupported operation: Could not access the sql.js javascript library`,
> make sure:
>
> 1. `drift_flutter` is listed in `pubspec.yaml` and `flutter pub get`
>    has been run.
> 2. The `sql-wasm.js` script tag is present in `web/index.html`.
> 3. The CDN at `https://github.com/simolus3/sql.js-wasm/...` is reachable
>    from the browser that opens the app.

## Testing

```bash
flutter test
flutter analyze
```

## License

[MIT](LICENSE)

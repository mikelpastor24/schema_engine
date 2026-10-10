# schema_ui example

A runnable Flutter application demonstrating theme-aware JSON Schema forms,
optional fields, array editing, a custom multiline biography editor, validation,
JSON submission, and reset. This application is a member of the repository's
Pub workspace and uses the local `schema_engine` and `schema_ui` packages.

## Run in a browser

From the repository root:

```sh
flutter pub get
cd packages/schema_ui/example
flutter run -d chrome
```

On Windows, `flutter run -d edge` also works with Microsoft Edge. To use another
browser, run `flutter run -d web-server` and open the printed local URL.
These options follow Flutter's [web development workflow](https://docs.flutter.dev/platform-integration/web/building).

## Run on Windows

From this application directory:

```sh
flutter run -d windows
```

The desktop build requires the Windows development toolchain described in
Flutter's [Windows setup guide](https://docs.flutter.dev/platform-integration/windows/setup).
Run `flutter doctor -v` to inspect the local toolchain.

## Use the example

Edit the name, active flag, and role. Enable optional properties to edit a
biography, age, or tags. Biography uses a custom multiline `TextFormField`.
Select **Save instance** to validate and display the JSON, or **Reset** to
restore the initial instance. The screen follows the system's light/dark theme.

## Checks

From this application directory:

```sh
flutter test --no-pub
flutter build web --no-pub
```

The repository's `dart run tool/check.dart` also runs this application's widget
test alongside engine and UI package tests. The entry point is
[lib/main.dart](lib/main.dart).

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

Edit the name, active flag, and role. Biography, age, amount, email, website,
and tags are always visible and marked optional. Untouched optional fields stay
out of the saved JSON; clearing them removes their properties. Age uses an
integer keyboard; amount uses a decimal keyboard and formatter. Email and
website use format-aware keyboards. Biography uses a custom multiline
`TextFormField`.

The example enables `SchemaOptions(assertFormats: true)` so email and website
values are checked against their `email` and `uri` formats. For example,
`12231312312` is invalid in either field; `reader@example.com` and
`https://example.com` are valid. Invalid values show the engine's schema
diagnostics in their fields and prevent submission. Empty optional fields are
omitted and do not trigger format errors. The engine's standard dialects treat
formats as annotations unless format assertions are enabled.

Select **Save instance** to validate and display the JSON, or **Reset** to
restore the initial instance. Editing after a successful save clears the
displayed JSON until the next valid submission. The screen follows the system's
light/dark theme.

`ExampleApp` accepts `messages: SchemaFormMessages(...)` to customize or
translate form text. The biography override uses `field.label` so its optional
marker follows the same configuration as the default editors. See
[form localization](../README.md#localize-form-messages) for the available
messages and integration with an application's localization system.
Validation errors include expected types, limits, and format names. Pass a
shared engine catalog as `SchemaFormMessages(validationError: catalog.format)`
to customize those diagnostics alongside the form's labels and actions.

## Checks

From this application directory:

```sh
flutter test --no-pub
flutter build web --no-pub
```

The repository's `dart run tool/check.dart` also runs this application's widget
test alongside engine and UI package tests. The entry point is
[lib/main.dart](lib/main.dart).

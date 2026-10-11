# Running the schema_ui example

A runnable Flutter application demonstrating theme-aware JSON Schema forms,
optional fields, array editing, a custom multiline biography editor, validation,
JSON submission, reset, and synchronized visual/JSON schema authoring. This
application is a member of the repository's
Pub workspace and uses the local `schema_engine` and `schema_ui` packages.

The application's directory is `packages/schema_ui/example`. Run commands
described as application-local from that directory.

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

## Run from a downloaded package archive

The published example retains its workspace configuration. To run a downloaded
copy outside this repository, create `pubspec_overrides.yaml` in this application
directory with the following content:

```yaml
resolution:
```

Then run `flutter pub get` and `flutter run -d chrome` from this directory. This
resolves `schema_engine: ^1.0.0` and `schema_ui: ^1.0.0` from pub.dev, so both
packages must already be published. The override uses the documented
[independent workspace resolution](https://dart.dev/tools/pub/workspaces#temporarily-resolving-a-package-outside-its-workspace)
procedure and is unnecessary when running the repository checkout.

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
[form localization](usage.md#localize-form-messages) for the available
messages and integration with an application's localization system.
Validation errors include expected types, limits, and format names. Pass a
shared engine catalog as `SchemaFormMessages(validationError: catalog.format)`
to customize those diagnostics alongside the form's labels and actions.

## Create or import a schema

Open **Schema builder** from the app bar. On wide screens the visual editor
appears on the left and the JSON code editor on the right. On narrow screens
the panels stack vertically. Both use the surrounding Material theme.

Add properties, select their types, mark required fields, configure constraints
and formats, and create reusable definitions. Visual edits update the formatted
JSON immediately after a valid change. Edit or paste a Draft 2020-12 schema
in the JSON panel to replace the visual document, including nested properties,
array items, and definitions. Unedited keywords without visual controls remain
in the schema. Entries group name and type without repeating the name in a
heading. Common limits and formats are visible. **More options** sits before the
schema's child properties and items, with **Validation** and **Annotations** tabs
to show one group of settings at a time. JSON updates retain selected tabs and
expanded sections at unchanged locations and keep the visual scroll position
while the content
still accommodates it.

Malformed JSON, invalid keyword values, unresolved references, and older drafts
show an error alongside the code while keeping the current visual document.
Invalid visual input keeps the last valid JSON until corrected. Export remains
disabled while either panel has errors. **Format JSON** normalizes formatting,
**Copy JSON** copies the current document, and **Reset schema** restores the
sample contact schema.

## Checks

From this application directory:

```sh
flutter test --no-pub
flutter build web --no-pub
```

The repository's `dart run tool/check.dart` also runs this application's widget
test alongside engine and UI package tests. The entry point is
[lib/main.dart](../example/lib/main.dart).

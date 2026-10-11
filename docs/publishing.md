# Publishing to pub.dev

Both packages are prepared as version `1.0.0`. Publishing requires a Google
Account. The repository workspace and the Flutter example have
`publish_to: none`; publish only the two library packages.

1. Commit the release changes and push them to the public repository so the
   package pages' source and documentation links match the release.
2. From the repository root, run `dart run tool/check.dart` with Flutter 3.47
   or later and Dart 3.13 or later.
3. Check and publish the engine from its package directory:

   ```sh
   cd packages/schema_engine
   dart pub publish --dry-run
   dart pub publish
   ```

   Review the file list, complete Google authentication if requested, and
   confirm the upload. Wait until `schema_engine` version `1.0.0` is available
   on pub.dev before publishing the UI package.

4. From the repository root, check and publish the UI:

   ```sh
   cd packages/schema_ui
   flutter pub publish --dry-run
   flutter pub publish
   ```

   Resolve any warnings before uploading. Workspace resolution uses the local
   engine; a successful UI dry run does not by itself establish that the hosted
   engine dependency is already available.

5. In a separate Flutter project outside this workspace, run
   `flutter pub add schema_engine schema_ui` to verify that consumers can resolve
   both hosted packages. Review the generated README, example, API documentation,
   and analysis report on each package's pub.dev page.

The first upload assigns the package to the Google Account used to authenticate.
A verified publisher is optional: create one with a domain you control, verify
the domain, and transfer each package through its pub.dev Admin tab after the
first upload. Subsequent releases must use a new version number and update the
corresponding changelog and inter-package dependency constraints.

See the official [publishing guide](https://dart.dev/tools/pub/publishing),
[publish command](https://dart.dev/tools/pub/cmd/pub-lish),
[workspace dependency rules](https://dart.dev/tools/pub/workspaces), and
[package scoring guide](https://pub.dev/help/scoring).

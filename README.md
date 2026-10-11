# Schema packages

Dart and Flutter packages for creating JSON Schemas, validating JSON data, and
building visual editors and forms from the same schema.

| Package | What it does | Requirements |
| --- | --- | --- |
| [schema_engine](packages/schema_engine) | Parse, build, serialize, and validate JSON Schemas and their instances | Dart 3.13 or later |
| [schema_ui](packages/schema_ui) | Create schemas visually and edit JSON instances with themed Flutter forms | Flutter 3.47 and Dart 3.13 or later |

Use the engine in Dart or Flutter applications. Add the UI package when you need
visual schema authoring or instance forms. Each package README includes its
features, limitations, installation instructions, and a short example.

The [example application](packages/schema_ui/example) demonstrates instance
editing and a schema builder with synchronized visual and JSON views.

See the [documentation](docs/README.md) for detailed usage, development,
compatibility, measurements, and publishing.

Original implementation, licensed under [MIT](LICENSE).

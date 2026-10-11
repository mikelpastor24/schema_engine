part of 'schema_editor.dart';

class _SchemaEditorOptions extends StatelessWidget {
  const _SchemaEditorOptions({
    super.key,
    required this.messages,
    required this.spacing,
    required this.validation,
    required this.annotations,
  });

  final SchemaEditorMessages messages;
  final double spacing;
  final Widget validation;
  final Widget annotations;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: ExpansionTile(
      leading: const Icon(Icons.tune),
      title: Text(messages.settings),
      dense: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.only(top: spacing / 2),
      shape: const Border(),
      collapsedShape: const Border(),
      maintainState: true,
      children: [
        TabBar.secondary(
          tabs: [
            Tab(text: messages.validation),
            Tab(text: messages.annotations),
          ],
        ),
        SizedBox(height: spacing),
        Builder(
          builder: (context) {
            final controller = DefaultTabController.of(context);
            return ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, content) in [
                    (0, validation),
                    (1, annotations),
                  ])
                    // Hidden fields stay registered with the ancestor Form.
                    Offstage(
                      offstage: controller.index != index,
                      child: ExcludeFocus(
                        excluding: controller.index != index,
                        child: content,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}

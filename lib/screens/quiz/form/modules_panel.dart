import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class ModulesPanel extends StatelessWidget {
  final List<String> modulesList;
  final TextEditingController moduleController;
  final Map<String, TextEditingController> moduleTagControllers;
  final bool importEnabled;
  final VoidCallback onShowImportDialog;
  final VoidCallback onAddModule;
  final Function(int, int) onMoveModule;
  final Function(String) onRemoveModule;
  final Function(String) onScrollToModule;
  final bool completeRandomShuffle;
  final ValueChanged<bool> onCompleteRandomShuffleChanged;
  final bool shuffleModules;
  final ValueChanged<bool> onShuffleModulesChanged;
  final bool shuffleQuestionsWithinModules;
  final ValueChanged<bool> onShuffleQuestionsWithinModulesChanged;

  const ModulesPanel({
    super.key,
    required this.modulesList,
    required this.moduleController,
    required this.moduleTagControllers,
    required this.importEnabled,
    required this.onShowImportDialog,
    required this.onAddModule,
    required this.onMoveModule,
    required this.onRemoveModule,
    required this.onScrollToModule,
    required this.completeRandomShuffle,
    required this.onCompleteRandomShuffleChanged,
    required this.shuffleModules,
    required this.onShuffleModulesChanged,
    required this.shuffleQuestionsWithinModules,
    required this.onShuffleQuestionsWithinModulesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Modules",
              style: GoogleFonts.poppins(
                color: global.valueColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (importEnabled)
              TextButton.icon(
                onPressed: onShowImportDialog,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text("IMPORT MORE"),
                style: TextButton.styleFrom(
                  foregroundColor: global.primaryAccent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: moduleController,
                style: const TextStyle(color: global.valueColor),
                decoration: const InputDecoration(
                  labelText: "New Module Name",
                  hintText: "e.g. Mathematics, Science...",
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onAddModule,
              style: ElevatedButton.styleFrom(
                backgroundColor: global.primaryAccent,
              ),
              child: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...modulesList.asMap().entries.map((entry) {
          final int index = entry.key;
          final String m = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: global.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: global.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.folder_open,
                        color: global.primaryAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.toUpperCase(),
                          style: const TextStyle(
                            color: global.valueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        onPressed: index > 0
                            ? () => onMoveModule(index, index - 1)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        onPressed: index < modulesList.length - 1
                            ? () => onMoveModule(index, index + 1)
                            : null,
                      ),
                      if (m != "General")
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: global.errorColor,
                            size: 20,
                          ),
                          onPressed: () => onRemoveModule(m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => onScrollToModule(m),
                    icon: const Icon(Icons.near_me_outlined, size: 14),
                    label: const Text(
                      "Go to Questions",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextField(
                    controller: moduleTagControllers[m],
                    style: const TextStyle(
                      color: global.valueColor,
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Sub Topics / Tags (comma separated)",
                      hintText: "topic1, topic2...",
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: global.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: global.borderColor),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  "Complete Random Shuffle",
                  style: TextStyle(color: global.valueColor, fontSize: 14),
                ),
                subtitle: const Text(
                  "Mix all questions across all modules",
                  style: TextStyle(color: global.labelColor, fontSize: 11),
                ),
                value: completeRandomShuffle,
                activeThumbColor: global.primaryAccent,
                onChanged: onCompleteRandomShuffleChanged,
              ),
              if (!completeRandomShuffle) ...[
                const Divider(color: global.borderColor, height: 1),
                SwitchListTile(
                  title: const Text(
                    "Shuffle Modules",
                    style: TextStyle(color: global.valueColor, fontSize: 14),
                  ),
                  value: shuffleModules,
                  activeThumbColor: global.primaryAccent,
                  onChanged: onShuffleModulesChanged,
                ),
                const Divider(color: global.borderColor, height: 1),
                SwitchListTile(
                  title: const Text(
                    "Shuffle Within Modules",
                    style: TextStyle(color: global.valueColor, fontSize: 14),
                  ),
                  value: shuffleQuestionsWithinModules,
                  activeThumbColor: global.primaryAccent,
                  onChanged: onShuffleQuestionsWithinModulesChanged,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

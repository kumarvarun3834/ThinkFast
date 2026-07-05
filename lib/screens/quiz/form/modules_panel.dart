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
    return Material(
      color: global.cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: global.borderColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.view_module_outlined, color: global.primaryAccent),
                    const SizedBox(width: 12),
                    Text(
                      "Modules",
                      style: GoogleFonts.poppins(
                        color: global.valueColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (importEnabled)
                  TextButton.icon(
                    onPressed: onShowImportDialog,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text("IMPORT MORE"),
                    style: TextButton.styleFrom(
                      foregroundColor: global.primaryAccent,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: moduleController,
                    style: const TextStyle(color: global.valueColor, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: "New Module Name",
                      hintText: "e.g. Mathematics, Science...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onAddModule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: global.primaryAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...modulesList.asMap().entries.map((entry) => _buildModuleBlock(entry.key, entry.value)),
            const SizedBox(height: 8),
            _buildShuffleBlock(),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleBlock(int index, String m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: global.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open_rounded, color: global.labelColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.toUpperCase(),
                  style: const TextStyle(
                    color: global.valueColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 16, color: global.labelColor),
                onPressed: index > 0 ? () => onMoveModule(index, index - 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 16, color: global.labelColor),
                onPressed: index < modulesList.length - 1 ? () => onMoveModule(index, index + 1) : null,
              ),
              if (m != "General")
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: global.errorColor, size: 18),
                  onPressed: () => onRemoveModule(m),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: moduleTagControllers[m],
            style: const TextStyle(color: global.valueColor, fontSize: 12),
            decoration: const InputDecoration(
              labelText: "Sub Topics / Tags (comma separated)",
              hintText: "topic1, topic2...",
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onScrollToModule(m),
              icon: const Icon(Icons.near_me_outlined, size: 14),
              label: const Text("Go to Questions", style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(foregroundColor: global.primaryAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShuffleBlock() {
    return Material(
      color: global.cardColor.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            dense: true,
            title: const Text(
              "Complete Random Shuffle",
              style: TextStyle(color: global.valueColor, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              "Mix all questions across all modules",
              style: TextStyle(color: global.labelColor, fontSize: 10),
            ),
            value: completeRandomShuffle,
            activeColor: global.primaryAccent,
            onChanged: onCompleteRandomShuffleChanged,
          ),
          if (!completeRandomShuffle) ...[
            const Divider(color: global.borderColor, height: 1),
            SwitchListTile(
              dense: true,
              title: const Text("Shuffle Modules", style: TextStyle(color: global.valueColor, fontSize: 13)),
              value: shuffleModules,
              activeColor: global.primaryAccent,
              onChanged: onShuffleModulesChanged,
            ),
            const Divider(color: global.borderColor, height: 1),
            SwitchListTile(
              dense: true,
              title: const Text("Shuffle Within Modules", style: TextStyle(color: global.valueColor, fontSize: 13)),
              value: shuffleQuestionsWithinModules,
              activeColor: global.primaryAccent,
              onChanged: onShuffleQuestionsWithinModulesChanged,
            ),
          ],
        ],
      ),
    );
  }
}

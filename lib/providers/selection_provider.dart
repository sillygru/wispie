import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SelectionPhase { inactive, selecting }

sealed class SelectionState {
  const SelectionState._();

  SelectionPhase get phase;
  bool get isSelectionMode => phase == SelectionPhase.selecting;
  Set<String> get selectedFilenames;

  const factory SelectionState.inactive() = _InactiveSelectionState;
  const factory SelectionState.active(Set<String> selectedFilenames) =
      _ActiveSelectionState;

  factory SelectionState({
    bool isSelectionMode = false,
    Set<String>? selectedFilenames,
  }) {
    if (!isSelectionMode ||
        selectedFilenames == null ||
        selectedFilenames.isEmpty) {
      return const SelectionState.inactive();
    }
    return SelectionState.active(Set.unmodifiable(selectedFilenames));
  }

  SelectionState copyWith({
    bool? isSelectionMode,
    Set<String>? selectedFilenames,
  });
}

class _InactiveSelectionState extends SelectionState {
  const _InactiveSelectionState() : super._();

  @override
  SelectionPhase get phase => SelectionPhase.inactive;

  @override
  Set<String> get selectedFilenames => const <String>{};

  @override
  SelectionState copyWith({
    bool? isSelectionMode,
    Set<String>? selectedFilenames,
  }) {
    final mode = isSelectionMode ?? false;
    final files = selectedFilenames ?? const <String>{};
    return SelectionState(isSelectionMode: mode, selectedFilenames: files);
  }
}

class _ActiveSelectionState extends SelectionState {
  @override
  final Set<String> selectedFilenames;

  const _ActiveSelectionState(this.selectedFilenames) : super._();

  @override
  SelectionPhase get phase => SelectionPhase.selecting;

  @override
  SelectionState copyWith({
    bool? isSelectionMode,
    Set<String>? selectedFilenames,
  }) {
    final mode = isSelectionMode ?? true;
    final files = selectedFilenames ?? this.selectedFilenames;
    return SelectionState(isSelectionMode: mode, selectedFilenames: files);
  }
}

class SelectionNotifier extends Notifier<SelectionState> {
  @override
  SelectionState build() => const SelectionState.inactive();

  void toggleSelectionMode() {
    state = const SelectionState.inactive();
  }

  void enterSelectionMode(String initialFilename) {
    state = SelectionState.active({initialFilename});
  }

  void exitSelectionMode() {
    state = const SelectionState.inactive();
  }

  void toggleSelection(String filename) {
    final current = Set<String>.from(state.selectedFilenames);
    if (current.contains(filename)) {
      current.remove(filename);
      if (current.isEmpty) {
        state = const SelectionState.inactive();
        return;
      }
    } else {
      current.add(filename);
    }
    state = SelectionState.active(current);
  }

  void selectAll(List<String> filenames) {
    if (filenames.isEmpty) {
      state = const SelectionState.inactive();
      return;
    }
    state = SelectionState.active(Set<String>.from(filenames));
  }

  List<String> getOrderedSelection() {
    return state.selectedFilenames.toList();
  }
}

final selectionProvider =
    NotifierProvider<SelectionNotifier, SelectionState>(() {
  return SelectionNotifier();
});

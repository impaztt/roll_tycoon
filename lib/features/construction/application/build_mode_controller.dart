import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../park/domain/facility.dart';

/// What kind of thing the player has selected to build (if any).
sealed class BuildSelection {
  const BuildSelection();
}

class FacilitySelection extends BuildSelection {
  final FacilityMaster master;
  const FacilitySelection(this.master);
}

class PathSelection extends BuildSelection {
  const PathSelection();
}

class HireJanitorSelection extends BuildSelection {
  const HireJanitorSelection();
}

class DemolishSelection extends BuildSelection {
  const DemolishSelection();
}

/// UI mode (per design doc §9.2 camera modes — operate vs build).
enum UiMode { operating, building }

class UiState {
  final UiMode mode;
  final BuildSelection? selection;
  final String? selectedFacilityInstanceId;
  final String? lastMessage;
  const UiState({
    required this.mode,
    this.selection,
    this.selectedFacilityInstanceId,
    this.lastMessage,
  });

  UiState copyWith({
    UiMode? mode,
    BuildSelection? selection,
    bool clearSelection = false,
    String? selectedFacilityInstanceId,
    bool clearFacilitySelection = false,
    String? lastMessage,
    bool clearMessage = false,
  }) =>
      UiState(
        mode: mode ?? this.mode,
        selection: clearSelection ? null : (selection ?? this.selection),
        selectedFacilityInstanceId: clearFacilitySelection
            ? null
            : (selectedFacilityInstanceId ?? this.selectedFacilityInstanceId),
        lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      );

  static const initial = UiState(mode: UiMode.operating);
}

class UiController extends StateNotifier<UiState> {
  UiController() : super(UiState.initial);

  void enterBuildMode() {
    state = state.copyWith(
      mode: UiMode.building,
      clearFacilitySelection: true,
    );
  }

  void exitBuildMode() {
    state = state.copyWith(
      mode: UiMode.operating,
      clearSelection: true,
    );
  }

  void selectFacilityToBuild(FacilityMaster master) {
    state = state.copyWith(selection: FacilitySelection(master));
  }

  void selectPath() {
    state = state.copyWith(selection: const PathSelection());
  }

  void selectHireJanitor() {
    state = state.copyWith(selection: const HireJanitorSelection());
  }

  void selectDemolish() {
    state = state.copyWith(selection: const DemolishSelection());
  }

  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }

  void selectPlacedFacility(String? instanceId) {
    if (instanceId == null) {
      state = state.copyWith(clearFacilitySelection: true);
    } else {
      state = state.copyWith(selectedFacilityInstanceId: instanceId);
    }
  }

  void showMessage(String msg) {
    state = state.copyWith(lastMessage: msg);
  }

  void dismissMessage() {
    state = state.copyWith(clearMessage: true);
  }
}

final uiControllerProvider =
    StateNotifierProvider<UiController, UiState>((ref) => UiController());

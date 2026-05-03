import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../globe/presentation/globe_view.dart';
import '../../parcel/presentation/parcel_view.dart';
import '../application/country_controller.dart';

/// Top-level shell that flips between the globe view and the parcel view
/// with a smooth fade+scale transition.
///
/// Both views own their own gestures and overlays — this widget just
/// decides which one is on screen based on `activeParcelId`.
class CountryRoot extends ConsumerWidget {
  const CountryRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(countryControllerProvider);
    final inParcel = state.activeParcelId != null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // Default layoutBuilder gives children loose constraints, which lets
      // each child Scaffold shrink-wrap and end up tiny at the top of the
      // screen on mobile. Force children to fill via Positioned.fill.
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final c in previousChildren) Positioned.fill(child: c),
            if (currentChild != null) Positioned.fill(child: currentChild),
          ],
        );
      },
      transitionBuilder: (child, anim) {
        // Zoom-in feel: parcel scales up from 0.85 with fade,
        // globe fades back in scaling down from 1.05.
        final isParcel = child.key == const ValueKey('parcel');
        final scale = Tween<double>(
          begin: isParcel ? 0.85 : 1.05,
          end: 1.0,
        ).animate(anim);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      child: inParcel
          ? const KeyedSubtree(
              key: ValueKey('parcel'),
              child: ParcelView(),
            )
          : const KeyedSubtree(
              key: ValueKey('globe'),
              child: GlobeView(),
            ),
    );
  }
}

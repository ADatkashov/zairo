import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/city_providers.dart';

class CitySelectionScreen extends ConsumerWidget {
  const CitySelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final citiesAsync = ref.watch(activeCitiesProvider);
    final currentCityAsync = ref.watch(userCurrentCityProvider);
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          l10n.selectCity,
          style: textTheme.headlineSmall?.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: true,
        iconTheme: IconThemeData(color: colors.text),
      ),
      body: citiesAsync.when(
        data: (cities) {
          return currentCityAsync.when(
            data: (currentCity) {
              return ListView.separated(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                itemCount: cities.length,
                separatorBuilder: (context, index) =>
                    Divider(color: colors.border, height: 1),
                itemBuilder: (context, index) {
                  final city = cities[index];
                  final isSelected = currentCity?.code == city.code;

                  return GestureDetector(
                    onTap: () => _selectCity(context, ref, city.code),
                    child: Container(
                      color: colors.bg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: FactorySpacing.space4,
                        vertical: FactorySpacing.space3,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  city.name,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: colors.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (city.nameKk != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    city.nameKk!,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Symbols.check_circle,
                              color: colors.primary,
                              fill: 1,
                            )
                          else
                            Icon(
                              Symbols.radio_button_unchecked,
                              color: colors.border,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error: $error'),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading cities: $error'),
        ),
      ),
    );
  }

  Future<void> _selectCity(
    BuildContext context,
    WidgetRef ref,
    String cityCode,
  ) async {
    // Show loading
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading...')),
      );
    }

    // Select city via provider
    final notifier = ref.read(citySelectionProvider.notifier);
    await notifier.selectCity(cityCode);

    if (context.mounted) {
      // Refresh the city provider to get updated data
      ref.invalidate(userCurrentCityProvider);

      // Pop back and navigate to home
      context.pop();
    }
  }
}

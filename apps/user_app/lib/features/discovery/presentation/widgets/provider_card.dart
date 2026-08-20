import 'package:flutter/material.dart';

import '../../data/models/provider_search_result.dart';

class ProviderCard extends StatelessWidget {
  final ProviderSearchResult result;
  final VoidCallback? onTap;

  const ProviderCard({super.key, required this.result, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(result.name, style: theme.textTheme.titleMedium),
                  ),
                  if (result.hasOpenAvailability)
                    Chip(
                      label: const Text('Available'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.primaryContainer,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(result.vertical, style: theme.textTheme.bodySmall),
              if (result.distanceKm != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${result.distanceKm!.toStringAsFixed(1)} km away',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (result.minPrice != null) ...[
                const SizedBox(height: 8),
                Text(
                  'From ${result.minPrice!.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              if (result.services.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: result.services
                      .map((service) => Chip(
                            label: Text(service.title),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

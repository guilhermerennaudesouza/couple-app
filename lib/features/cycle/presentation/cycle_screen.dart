import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:couple_app/core/l10n/app_strings.dart';
import 'package:couple_app/core/theme/app_theme.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/cycle/data/cycle_repository.dart';
import 'package:couple_app/features/cycle/domain/cycle_model.dart';

class CycleScreen extends ConsumerWidget {
  final String coupleId;

  const CycleScreen({
    super.key,
    required this.coupleId,
  });

  Color _phaseColor(String phase) {
    switch (phase) {
      case CycleDataModel.phaseMenstrual:
        return const Color(0xFFE11D48); // Rose Red
      case CycleDataModel.phaseFollicular:
        return const Color(0xFF10B981); // Fresh Mint
      case CycleDataModel.phaseOvulation:
        return const Color(0xFFF59E0B); // Golden Glow
      case CycleDataModel.phaseLuteal:
      default:
        return const Color(0xFF8B5CF6); // Soft Violet
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final cycleAsync = ref.watch(cycleDataStreamProvider(coupleId));
    final coupleAsync = ref.watch(coupleStreamProvider(coupleId));

    String myUid = 'local_user';
    try {
      myUid = ref.read(pairingRepositoryProvider).currentUserUid ?? 'local_user';
    } catch (_) {}
    final myName =
        coupleAsync.valueOrNull?.getMyProfile(myUid)?.name ?? 'Seu Amor';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(strings.hubCycleTitle),
        actions: [
          if (cycleAsync.valueOrNull != null)
            IconButton(
              tooltip: 'Configurar Datas do Ciclo',
              onPressed: () => _showCycleSettingsModal(
                context,
                ref,
                cycleAsync.valueOrNull!,
              ),
              icon: const Icon(Icons.tune_rounded),
            ),
        ],
      ),
      body: cycleAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRose),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Erro ao carregar dados do ciclo: $err',
              style: TextStyle(color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (cycle) {
          final phase = cycle.currentPhase();
          final accent = _phaseColor(phase);
          final currentDay = cycle.currentCycleDay();
          final daysLeft = cycle.daysUntilNextPeriod();
          final nextDateStr =
              DateFormat("d 'de' MMMM", 'pt_BR').format(cycle.nextPeriodDate());

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
            children: [
              // Active Care Request Banner ("SOS Carinho")
              if ((cycle.activeCareRequest ?? '').isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRose.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryRose.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('💌', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PEDIDO DE CARINHO ATIVO (${(cycle.careRequestedByName ?? 'Amor').toUpperCase()})',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: AppTheme.primaryRose,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cycle.activeCareRequest!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Marcar como atendido',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(cycleRepositoryProvider)
                              .clearCareRequest(coupleId);
                        },
                        icon: const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.primaryRose,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Hero Cycle Phase Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: context.isDarkMode
                        ? [
                            accent.withValues(alpha: 0.25),
                            const Color(0xFF1A161F),
                          ]
                        : [
                            accent.withValues(alpha: 0.14),
                            Colors.white,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'DIA $currentDay DE ${cycle.cycleLength}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: accent,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _showCycleSettingsModal(context, ref, cycle),
                          icon: Icon(Icons.edit_calendar_rounded,
                              size: 16, color: accent),
                          label: Text(
                            'Ajustar Datas',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cycle.phaseTitlePt(),
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: context.textPrimary,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Próximo ciclo previsto em $daysLeft dias ($nextDateStr)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.cardColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.outlineColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tips_and_updates_rounded,
                                  size: 18, color: accent),
                              const SizedBox(width: 8),
                              Text(
                                'DICA DE CUIDADO PARA O CASAL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cycle.phasePartnerTipPt(),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: context.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Daily Symptoms & Mood Chips
              Text(
                'COMO ESTOU ME SENTINDO HOJE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CycleRepository.availableSymptoms.map((symptom) {
                  final isSelected = cycle.currentSymptoms.contains(symptom);
                  return FilterChip(
                    label: Text(symptom),
                    selected: isSelected,
                    selectedColor: accent.withValues(alpha: 0.22),
                    checkmarkColor: accent,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: isSelected ? accent : context.textPrimary,
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      ref.read(cycleRepositoryProvider).toggleSymptom(
                            coupleId,
                            cycle,
                            symptom,
                          );
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 26),

              // Partner Care Requests ("SOS Carinho")
              Text(
                'PEDIDOS DE CARINHO (AVISAR MEU AMOR 💕)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ...CycleRepository.careRequests.map((req) {
                final emoji = req['emoji'] ?? '💕';
                final title = req['title'] ?? '';
                final isCurrent = cycle.activeCareRequest == '$emoji $title';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isCurrent
                          ? AppTheme.primaryRose
                          : context.outlineColor,
                    ),
                  ),
                  child: ListTile(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      await ref.read(cycleRepositoryProvider).sendCareRequest(
                            coupleId,
                            requestText: '$emoji $title',
                            senderName: myName,
                          );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Pedido de carinho enviado: "$title" 💕',
                          ),
                        ),
                      );
                    },
                    leading: Text(emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: context.textPrimary,
                      ),
                    ),
                    trailing: Icon(
                      isCurrent
                          ? Icons.favorite_rounded
                          : Icons.send_rounded,
                      size: 18,
                      color: isCurrent
                          ? AppTheme.primaryRose
                          : context.textSecondary,
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _showCycleSettingsModal(
    BuildContext context,
    WidgetRef ref,
    CycleDataModel current,
  ) {
    DateTime pickedStart = current.lastPeriodStart;
    int cycleLength = current.cycleLength;
    int periodDuration = current.periodDuration;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 22,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configurar Ciclo 🩸',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Primeiro dia da última menstruação',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat("d 'de' MMMM 'de' y", 'pt_BR')
                          .format(pickedStart),
                      style: const TextStyle(
                        color: AppTheme.primaryRose,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: pickedStart,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 90)),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setModalState(() => pickedStart = date);
                        }
                      },
                      child: const Text('Escolher Data'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Duração média do ciclo (dias):',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: cycleLength > 21
                            ? () => setModalState(() => cycleLength--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$cycleLength',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        onPressed: cycleLength < 40
                            ? () => setModalState(() => cycleLength++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Duração do fluxo (dias):',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: periodDuration > 2
                            ? () => setModalState(() => periodDuration--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$periodDuration',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        onPressed: periodDuration < 10
                            ? () => setModalState(() => periodDuration++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await ref
                            .read(cycleRepositoryProvider)
                            .saveCycleSettings(
                              coupleId,
                              lastPeriodStart: pickedStart,
                              cycleLength: cycleLength,
                              periodDuration: periodDuration,
                            );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryRose,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Salvar Configurações 💕',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

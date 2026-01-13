import 'package:flutter/material.dart';

class HomeSectionWidget extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> items;
  final VoidCallback? onSeeAll;

  const HomeSectionWidget({
    super.key,
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    required this.items,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: EdgeInsets.zero, // Margem removida para controle externo e limpeza
      padding: const EdgeInsets.all(16), // Padding interno aumentado e unificado
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // Borda 16px
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), // Sombra Material 3 leve
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.only(bottom: 12), // Espaço header-grid
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                GestureDetector(
                  onTap: onToggle,
                  child: Text(
                    isExpanded ? "OCULTAR" : "MOSTRAR",
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),
          ),

          if (isExpanded)
            Column(
              children: [
                const SizedBox(height: 8),

                // GRID
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero, // Padding removido pois o container já tem
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8, // Espaçamento reduzido
                    mainAxisSpacing: 8,
                    childAspectRatio: () {
                      final w = MediaQuery.sizeOf(context).width;
                      if (w <= 360) return 0.95;
                      if (w <= 420) return 1.02;
                      return 1.1;
                    }(),
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => items[i],
                ),

                if (onSeeAll != null) ...[
                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: onSeeAll,
                    child: Container(
                      height: 42,
                      width: double.infinity,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: const Text(
                        "VER TODOS",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                ],
              ],
            )
        ],
      ),
    );
  }
}

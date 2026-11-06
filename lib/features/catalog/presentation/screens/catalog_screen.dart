import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../domain/entities/jewelry_category.dart';
import '../../domain/entities/jewelry_piece.dart';
import '../controllers/catalog_controller.dart';
import '../widgets/jewelry_bottom_nav.dart';
import '../widgets/piece_card.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  final String? initialSearch;
  const CatalogScreen({super.key, this.initialCategory, this.initialSearch});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  JewelryCategory? _category;
  late final TextEditingController _search;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _category = switch (widget.initialCategory) {
      'collar' => JewelryCategory.necklace,
      'arete' => JewelryCategory.earring,
      'pulsera' => JewelryCategory.bracelet,
      _ => null,
    };
    _query = widget.initialSearch ?? '';
    _search = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<JewelryPiece> _filter(List<JewelryPiece> pieces) {
    return pieces.where((piece) {
      final byCategory = _category == null || piece.categoria == _category;
      final text = _query.trim().toLowerCase();
      final byText =
          text.isEmpty ||
          piece.nombre.toLowerCase().contains(text) ||
          (piece.material?.toLowerCase().contains(text) ?? false) ||
          (piece.descripcion?.toLowerCase().contains(text) ?? false);
      return byCategory && byText;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogControllerProvider);
    return Scaffold(
      backgroundColor: JoyeriaPalette.background,
      bottomNavigationBar: const JewelryBottomNav(isHome: false),
      body: SafeArea(
        bottom: false,
        child: catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Error al cargar el catálogo: $error'),
            ),
          ),
          data: (pieces) => _buildCatalog(pieces),
        ),
      ),
    );
  }

  Widget _buildCatalog(List<JewelryPiece> pieces) {
    final filtered = _filter(pieces);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                  color: JoyeriaPalette.espresso,
                  onPressed: () => context.go('/home'),
                ),
                const Expanded(
                  child: Text(
                    'Catálogo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 28,
                      color: JoyeriaPalette.espresso,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 67,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              scrollDirection: Axis.horizontal,
              children: [
                _chip('Todas', null),
                _chip('Collares', JewelryCategory.necklace),
                _chip('Aretes', JewelryCategory.earring),
                _chip('Pulseras', JewelryCategory.bracelet),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 15),
            child: TextField(
              controller: _search,
              onChanged: (text) => setState(() => _query = text),
              style: const TextStyle(
                fontSize: 14,
                color: JoyeriaPalette.espresso,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar joyas...',
                hintStyle: const TextStyle(color: JoyeriaPalette.muted),
                prefixIcon: const Icon(
                  Icons.search,
                  color: JoyeriaPalette.muted,
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close, color: JoyeriaPalette.muted),
                ),
                filled: true,
                fillColor: JoyeriaPalette.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: JoyeriaPalette.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: JoyeriaPalette.rose),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            child: Text(
              '${filtered.length} joyas',
              style: const TextStyle(color: JoyeriaPalette.muted, fontSize: 13),
            ),
          ),
        ),
        if (filtered.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No encontramos joyas con ese filtro.')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
            sliver: SliverGrid.builder(
              itemCount: filtered.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 21,
                crossAxisSpacing: 15,
                childAspectRatio: .67,
              ),
              itemBuilder: (context, index) {
                final piece = filtered[index];
                return PieceCard(
                  piece: piece,
                  onTap: () => context.push('/piece/${piece.id}'),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _chip(String label, JewelryCategory? category) {
    final selected = _category == category;
    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : JoyeriaPalette.espresso,
          ),
        ),
        selected: selected,
        onSelected: (_) => setState(() => _category = category),
        backgroundColor: JoyeriaPalette.surface,
        selectedColor: JoyeriaPalette.rose,
        side: BorderSide(
          color: selected ? JoyeriaPalette.rose : JoyeriaPalette.stroke,
        ),
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
    );
  }
}

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
    final text = _query.trim().toLowerCase();
    return pieces.where((piece) {
      final byCategory = _category == null || piece.categoria == _category;
      final byText = text.isEmpty ||
          piece.nombre.toLowerCase().contains(text) ||
          (piece.material?.toLowerCase().contains(text) ?? false) ||
          (piece.descripcion?.toLowerCase().contains(text) ?? false);
      return byCategory && byText;
    }).toList();
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _category = null;
    });
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
          data: _buildCatalog,
        ),
      ),
    );
  }

  Widget _buildCatalog(List<JewelryPiece> pieces) {
    final filtered = _filter(pieces);
    final hasFilters = _category != null || _query.trim().isNotEmpty;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                  color: JoyeriaPalette.espresso,
                ),
                const Expanded(
                  child: Text(
                    'Catálogo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 30,
                      color: JoyeriaPalette.espresso,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 12, 22, 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NUESTRA COLECCIÓN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: JoyeriaPalette.rose,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Encuentra tu próxima joya favorita',
                  style: TextStyle(
                    fontSize: 14,
                    color: JoyeriaPalette.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 70,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 12),
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
            padding: const EdgeInsets.fromLTRB(20, 3, 20, 12),
            child: TextField(
              controller: _search,
              onChanged: (text) => setState(() => _query = text),
              style: const TextStyle(
                fontSize: 14,
                color: JoyeriaPalette.espresso,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar una joya...',
                hintStyle: const TextStyle(color: JoyeriaPalette.muted),
                prefixIcon: const Icon(Icons.search_rounded, color: JoyeriaPalette.muted),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar búsqueda',
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded, color: JoyeriaPalette.muted),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 20, 12),
            child: Row(
              children: [
                Text(
                  '${filtered.length} ${filtered.length == 1 ? 'joya' : 'joyas'}',
                  style: const TextStyle(
                    color: JoyeriaPalette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (hasFilters)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text(
                      'Limpiar filtros',
                      style: TextStyle(color: JoyeriaPalette.rose, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded, size: 44, color: JoyeriaPalette.muted),
                    const SizedBox(height: 14),
                    const Text(
                      'No encontramos joyas',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 22,
                        color: JoyeriaPalette.espresso,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Prueba con otra palabra o categoría.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: JoyeriaPalette.muted),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Ver todas las joyas'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
            sliver: SliverGrid.builder(
              itemCount: filtered.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 22,
                crossAxisSpacing: 14,
                childAspectRatio: 0.64,
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
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      ),
    );
  }
}

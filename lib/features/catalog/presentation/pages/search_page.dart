import 'package:flutter/material.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/catalog_providers.dart';
import '../../domain/entities/catalog_entity.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Cari cookies...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: AppColors.outline),
          ),
          onSubmitted: (q) =>
              ref.read(searchNotifierProvider.notifier).search(q),
          textInputAction: TextInputAction.search,
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(searchNotifierProvider.notifier).clear();
              _controller.clear();
              context.pop();
            },
            child: const Text('Batal'),
          ),
        ],
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (_controller.text.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search, size: 48, color: AppColors.outline),
                  SizedBox(height: Responsive.spacing(context)),
                  const Text('Ketik untuk mencari produk',
                      style: TextStyle(color: AppColors.outline)),
                ],
              ),
            );
          }
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off,
                      size: 48, color: AppColors.outline),
                  SizedBox(height: Responsive.spacing(context)),
                  const Text('Tidak ada hasil ditemukan',
                      style: TextStyle(color: AppColors.outline)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.all(Responsive.padding(context)),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _buildResultItem(context, items[index]),
          );
        },
      ),
    );
  }

  Widget _buildResultItem(BuildContext context, ProductEntity product) {
    return ListTile(
      onTap: () => context.push('/product/${product.id}'),
      contentPadding: const EdgeInsets.all(8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: product.images.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: product.images.first,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.cookie, color: AppColors.primaryLight),
                )
              : const Icon(Icons.cookie, color: AppColors.primaryLight),
        ),
      ),
      title: Text(
        product.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        CurrencyFormatter.idr(product.price),
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

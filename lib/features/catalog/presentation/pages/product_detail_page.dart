import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../cart/data/cart_provider.dart';
import '../providers/catalog_providers.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailPage({required this.productId, super.key});

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(productDetailProvider.notifier).load(widget.productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productDetailProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Produk'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Gagal memuat produk', style: TextStyle(color: AppColors.onSurface)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(productDetailProvider.notifier).load(widget.productId),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (product) {
          if (product == null) {
            return const Center(child: Text('Produk tidak ditemukan'));
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    // Image carousel
                    AspectRatio(
                      aspectRatio: 1,
                      child: PageView.builder(
                        onPageChanged: (i) => setState(() => _selectedImageIndex = i),
                        itemCount: product.images.length,
                        itemBuilder: (context, index) {
                          return CachedNetworkImage(
                            imageUrl: product.images[index],
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                            errorWidget: (_, __, ___) => const Icon(Icons.cookie, size: 64, color: AppColors.primaryLight),
                          );
                        },
                      ),
                    ),

                    // Image indicators
                    if (product.images.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            product.images.length,
                            (i) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selectedImageIndex == i
                                    ? AppColors.primary
                                    : AppColors.outlineVariant,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Product info
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 18, color: AppColors.ratingColor),
                              const SizedBox(width: 4),
                              Text(
                                '${product.rating} (${product.reviewCount} ulasan)',
                                style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: product.stock > 0 ? AppColors.successContainer : AppColors.errorContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  product.stock > 0 ? 'Stok: ${product.stock}' : 'Habis',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: product.stock > 0 ? AppColors.success : AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (product.discountPrice != null) ...[
                            Text(
                              CurrencyFormatter.idr(product.discountPrice!),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.idr(product.price),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.originalPriceColor,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ] else
                            Text(
                              CurrencyFormatter.idr(product.price),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          const SizedBox(height: 20),
                          const Text(
                            'Deskripsi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product.description,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Add to cart button
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.outlineVariant)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: product.stock > 0 ? () {
                            ref.read(cartProvider.notifier).addItem(
                              int.tryParse(product.id) ?? 0,
                              product.name,
                              product.price,
                              image: product.images.isNotEmpty ? product.images.first : null,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.name} ditambahkan ke keranjang'),
                                backgroundColor: const Color(0xFF2E7D32),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          } : null,
                          icon: const Icon(Icons.shopping_cart, size: 20),
                          label: Text(
                            product.stock > 0 ? 'Tambah ke Keranjang' : 'Stok Habis',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

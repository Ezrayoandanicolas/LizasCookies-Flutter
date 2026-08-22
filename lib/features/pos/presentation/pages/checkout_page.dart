import 'package:flutter/material.dart';
import 'checkout_sheet.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: const CheckoutSheet(isPage: true),
    );
  }
}

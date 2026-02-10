import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchVoucherScreen extends StatelessWidget {
  const SearchVoucherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Search Vouchers',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter Voucher # or Amount',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
            const SizedBox(height: 32),
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text(
              'Enter search terms above',
              style: GoogleFonts.inter(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

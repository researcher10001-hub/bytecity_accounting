import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'dart:async';

class WelcomeHeader extends StatefulWidget {
  const WelcomeHeader({super.key});

  @override
  State<WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<WelcomeHeader> {
  late DateTime _currentTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(_currentTime);
    final timeStr = DateFormat('h:mm:ss a').format(_currentTime);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Assalamu Alaikum, ${user?.name.split(' ').first ?? 'User'}',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              const Text('👋', style: TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRoleBadge(user?.role ?? 'Viewer'),
              const SizedBox(width: 12),
              Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                '$dateStr | $timeStr',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color bgColor;
    Color textColor;

    switch (role) {
      case AppRoles.admin:
        bgColor = const Color(0xFFFFE0B2); // Orange[100]
        textColor = const Color(0xFFF57C00); // Orange[700]
        break;
      case AppRoles.management:
        bgColor = const Color(0xFFC8E6C9); // Green[100]
        textColor = const Color(0xFF388E3C); // Green[700]
        break;
      case AppRoles.businessOperationsAssociate:
        bgColor = const Color(0xFFB2DFDB); // Teal[100]
        textColor = const Color(0xFF00695C); // Teal[800]
        break;
      case AppRoles.viewer:
      case 'Owner': // Keep Owner if it's distinct or mapped to Viewer logic
        bgColor = const Color(0xFFBBDEFB); // Blue[100]
        textColor = const Color(0xFF1976D2); // Blue[700]
        break;
      default:
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

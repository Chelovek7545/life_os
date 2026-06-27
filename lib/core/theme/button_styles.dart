import 'package:flutter/material.dart';

final dateButtonStyle = OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFF171717),
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFF2A2A2A),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 28,
                              ),
                            ).copyWith(
                              overlayColor: WidgetStatePropertyAll(
                                Colors.white.withOpacity(0.06),
                              ),
                              iconColor: const WidgetStatePropertyAll(
                                Color(0xFFFFB39B),
                              ),
                            );
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/theme_extensions.dart';

/// Shows a premium, animated BottomSheet for Voice Search and returns the recognized text.
Future<String?> showVoiceSearchBottomSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const VoiceSearchBottomSheet(),
  );
}

class VoiceSearchBottomSheet extends StatefulWidget {
  const VoiceSearchBottomSheet({super.key});

  @override
  State<VoiceSearchBottomSheet> createState() => _VoiceSearchBottomSheetState();
}

class _VoiceSearchBottomSheetState extends State<VoiceSearchBottomSheet>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isInitializing = true;
  String _recognizedWords = '';
  String _errorMessage = '';
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );

      if (available && mounted) {
        setState(() {
          _isInitializing = false;
        });
        _startListening();
      } else if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'ไม่สามารถใช้งานระบบบันทึกเสียงได้';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'เกิดข้อผิดพลาดในการตรวจสอบสิทธิ์ไมโครโฟน';
        });
      }
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == 'listening') {
      setState(() {
        _isListening = true;
      });
      _rippleController.repeat();
    } else if (status == 'notListening' || status == 'done') {
      setState(() {
        _isListening = false;
      });
      _rippleController.stop();
      // Auto-return if we got words
      if (_recognizedWords.trim().isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            Navigator.of(context).pop(_recognizedWords.trim());
          }
        });
      }
    }
  }

  void _onSpeechError(dynamic error) {
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _rippleController.stop();
      if (error.errorMsg == 'error_permission') {
        _errorMessage = 'กรุณาอนุญาตสิทธิ์เข้าถึงไมโครโฟนในการตั้งค่าระบบ';
      } else {
        _errorMessage = 'สัญญาณขาดหาย กรุณาลองพูดใหม่อีกครั้ง';
      }
    });
  }

  void _startListening() async {
    setState(() {
      _recognizedWords = '';
      _errorMessage = '';
    });
    
    await _speech.listen(
      localeId: 'th_TH', // Thai language
      onResult: (result) {
        if (mounted) {
          setState(() {
            _recognizedWords = result.recognizedWords;
          });
        }
      },
    );
  }

  void _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
      _rippleController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF33BCB4);
    
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE0F5F4),
          width: 1,
        ),
      ),
      child: MainPrivateArea(
        isDark: isDark,
        primaryColor: primaryColor,
        isInitializing: _isInitializing,
        errorMessage: _errorMessage,
        isListening: _isListening,
        recognizedWords: _recognizedWords,
        rippleController: _rippleController,
        onRetry: _initSpeech,
        onStop: _stopListening,
        onConfirm: () => Navigator.of(context).pop(_recognizedWords.trim()),
      ),
    );
  }
}

class MainPrivateArea extends StatelessWidget {
  const MainPrivateArea({
    super.key,
    required this.isDark,
    required this.primaryColor,
    required this.isInitializing,
    required this.errorMessage,
    required this.isListening,
    required this.recognizedWords,
    required this.rippleController,
    required this.onRetry,
    required this.onStop,
    required this.onConfirm,
  });

  final bool isDark;
  final Color primaryColor;
  final bool isInitializing;
  final String errorMessage;
  final bool isListening;
  final String recognizedWords;
  final AnimationController rippleController;
  final VoidCallback onRetry;
  final VoidCallback onStop;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Drag handle
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),
        
        Text(
          isListening ? 'กำลังฟังเสียงของคุณ...' : 'ค้นหาด้วยเสียงพูด',
          style: kanitTextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'กรุณาพูดชื่อ เบอร์โทร หรือบ้านเลขที่ลูกค้า',
          style: kanitTextStyle(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 32),
        
        // Microphone Pulsing Ripples
        if (isInitializing)
          const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (errorMessage.isNotEmpty)
          Column(
            children: [
              Icon(Icons.error_outline, color: Colors.orange.shade600, size: 48),
              const SizedBox(height: 12),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: kanitTextStyle(fontSize: 13, color: Colors.orange.shade700),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองอีกครั้ง'),
              ),
            ],
          )
        else
          Stack(
            alignment: Alignment.center,
            children: [
              // Ripple animation layers
              AnimatedBuilder(
                animation: rippleController,
                builder: (context, child) {
                  return Container(
                    width: 100 + (rippleController.value * 60),
                    height: 100 + (rippleController.value * 60),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(
                        alpha: (1 - rippleController.value) * 0.25,
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: rippleController,
                builder: (context, child) {
                  return Container(
                    width: 80 + (rippleController.value * 30),
                    height: 80 + (rippleController.value * 30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(
                        alpha: (1 - rippleController.value) * 0.15,
                      ),
                    ),
                  );
                },
              ),
              
              // Central mic button
              GestureDetector(
                onTap: isListening ? onStop : onRetry,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isListening
                          ? [const Color(0xFFE57373), const Color(0xFFEF5350)] // Red when listening
                          : [primaryColor, const Color(0xFF2EA29B)], // Cyan/teal when idle
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isListening ? Colors.red : primaryColor)
                            .withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    isListening ? Icons.stop : Icons.mic_none,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ],
          ),
        
        const SizedBox(height: 36),
        
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              recognizedWords.isEmpty
                  ? (isListening ? 'กำลังแปลงเสียงพูด...' : 'แตะไมโครโฟนและเริ่มพูด')
                  : recognizedWords,
              textAlign: TextAlign.center,
              style: kanitTextStyle(
                fontSize: 16,
                fontWeight: recognizedWords.isEmpty ? FontWeight.normal : FontWeight.bold,
                color: recognizedWords.isEmpty
                    ? (isDark ? Colors.white30 : Colors.grey.shade400)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  'ยกเลิก',
                  style: kanitTextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
            if (recognizedWords.trim().isNotEmpty) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'ยืนยันค้นหา',
                    style: kanitTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

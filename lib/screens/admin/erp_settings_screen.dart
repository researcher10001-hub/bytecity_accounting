import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/settings_provider.dart';

class ERPSettingsScreen extends StatefulWidget {
  const ERPSettingsScreen({super.key});

  @override
  State<ERPSettingsScreen> createState() => _ERPSettingsScreenState();
}

class _ERPSettingsScreenState extends State<ERPSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiSecretController = TextEditingController();
  final _docTypeController = TextEditingController();
  bool _emailEnabled = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _urlController.text = settings.erpUrl;
    _apiKeyController.text = settings.erpApiKey;
    _apiSecretController.text = settings.erpApiSecret;
    _docTypeController.text = settings.erpDocType;
    _emailEnabled = settings.emailNotificationsEnabled;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _docTypeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final error = await context.read<SettingsProvider>().updateSettingsOnServer(
      erpUrl: _urlController.text.trim(),
      erpApiKey: _apiKeyController.text.trim(),
      erpApiSecret: _apiSecretController.text.trim(),
      erpDocType: _docTypeController.text.trim(),
      emailNotificationsEnabled: _emailEnabled,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ERP Settings updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'ERPNext Configuration',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Instance Details'),
              _buildTextField(
                controller: _urlController,
                label: 'ERP URL',
                hint: 'https://erp.example.com',
                icon: LucideIcons.link,
                helper: 'The base URL of your ERPNext instance.',
                validator: (val) {
                  if (val == null || val.isEmpty) return 'URL is required';
                  if (!val.startsWith('http')) return 'Enter a valid URL';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _docTypeController,
                label: 'Target DocType',
                hint: 'Journal Entry',
                icon: LucideIcons.fileText,
                helper: 'The type of document to create in ERPNext.',
              ),

              const SizedBox(height: 32),
              _buildSectionHeader('API Credentials'),
              _buildTextField(
                controller: _apiKeyController,
                label: 'API Key',
                icon: LucideIcons.key,
                helper: 'Generated from User settings in ERPNext.',
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _apiSecretController,
                label: 'API Secret',
                icon: LucideIcons.shield,
                isPassword: true,
                helper: 'The secret associated with your API key.',
              ),

              const SizedBox(height: 32),
              _buildSectionHeader('System Behavior'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SwitchListTile(
                  title: Text(
                    'Email Notifications',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Global toggle for automated emails.',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  value: _emailEnabled,
                  onChanged: (val) => setState(() => _emailEnabled = val),
                  activeThumbColor: const Color(0xFF2563EB),
                ),
              ),

              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Save Configuration',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? helper,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator:
              validator ??
              (val) {
                if (val == null || val.isEmpty) return 'Required';
                return null;
              },
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              helper,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ),
      ],
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spectrum_flutter/theme/app_colors.dart';
import 'package:spectrum_flutter/services/auth_service.dart';
import 'package:spectrum_flutter/services/app_config_server.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _appConfig = AppConfigServer();
  String? _localImagePath;

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() => _localImagePath = image.path);
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_appConfig.translate('profile_updated'), style: GoogleFonts.outfit()),
              backgroundColor: AppColors.accent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_appConfig.translate('update_failed')} $e', style: GoogleFonts.outfit()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _appConfig.addListener(_update);
  }

  @override
  void dispose() {
    _appConfig.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String displayName = user?.displayName?.isNotEmpty == true ? user!.displayName! : 'NutriVision User';
    final String email = user?.email ?? 'user@example.com';
    final String photoUrl = user?.photoURL ?? '';
    final bool isDark = _appConfig.isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_appConfig.translate('profile'), style: GoogleFonts.outfit(color: isDark ? Colors.white : AppColors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar Section
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent.withAlpha(51), width: 4),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 5),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: isDark ? const Color(0xFF1F2937) : AppColors.background,
                      backgroundImage: _localImagePath != null 
                        ? FileImage(File(_localImagePath!)) 
                        : (photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null) as ImageProvider<Object>?,
                      child: (_localImagePath == null && photoUrl.isEmpty) 
                        ? Text(displayName[0].toUpperCase(), style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.accent))
                        : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent, 
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? const Color(0xFF111827) : Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(displayName, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.black)),
            Text(email, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.grey)),
            const SizedBox(height: 32),

            // Profile Sections
            _buildProfileSection(
              title: _appConfig.translate('account_settings'),
              items: [
                _ProfileItem(
                  icon: Icons.person_outline_rounded, 
                  label: _appConfig.translate('personal_info'), 
                  color: Colors.blue,
                  onTap: () => _showPersonalInfoDialog(displayName, email),
                ),

                _ProfileItem(
                  icon: Icons.security_rounded, 
                  label: _appConfig.translate('privacy'), 
                  color: Colors.green,
                  onTap: () => _showPrivacyPolicy(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildProfileSection(
              title: _appConfig.translate('app_settings'),
              items: [
                _ProfileItem(
                  icon: Icons.language_rounded, 
                  label: _appConfig.translate('language'), 
                  color: Colors.purple, 
                  trailing: _appConfig.locale.languageCode == 'en' ? 'English' : 'हिंदी',
                  onTap: () => _showLanguageSelector(),
                ),
                _ProfileItem(
                  icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, 
                  label: _appConfig.translate('appearance'), 
                  color: Colors.indigo, 
                  trailing: isDark ? _appConfig.translate('dark_mode') : _appConfig.translate('light_mode'),
                  onTap: () => _appConfig.toggleTheme(),
                ),
                _ProfileItem(
                  icon: Icons.help_outline_rounded, 
                  label: _appConfig.translate('help'), 
                  color: Colors.teal,
                  onTap: () => _showHelpSupport(),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await AuthService().signOut();
                  if (!mounted) return;
                  if (navigator.canPop()) {
                    navigator.popUntil((route) => route.isFirst);
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                label: Text(_appConfig.translate('sign_out'), style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection({required String title, required List<_ProfileItem> items}) {
    final bool isDark = _appConfig.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.black)),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.lightGrey.withAlpha(isDark ? 20 : 128)),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10)],
          ),
          child: Column(
            children: List.generate(items.length, (index) {
              final item = items[index];
              return Column(
                children: [
                   ListTile(
                    onTap: item.onTap,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: item.color.withAlpha(26), borderRadius: BorderRadius.circular(12)),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    title: Text(item.label, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.white : AppColors.black)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.trailing != null) 
                          Text(item.trailing!, style: GoogleFonts.outfit(color: AppColors.grey, fontSize: 13)),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.grey, size: 20),
                      ],
                    ),
                  ),
                  if (index != items.length - 1) 
                    Divider(height: 1, color: AppColors.lightGrey.withAlpha(isDark ? 20 : 128), indent: 70),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // Functional Popups
  void _showPersonalInfoDialog(String name, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: _appConfig.isDarkMode ? const Color(0xFF1F2937) : Colors.white,
        title: Text(_appConfig.translate('personal_info'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _appConfig.isDarkMode ? Colors.white : AppColors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(_appConfig.translate('name_label'), name),
            const SizedBox(height: 12),
            _buildInfoRow(_appConfig.translate('email_label'), email),
            const SizedBox(height: 12),
            _buildInfoRow(_appConfig.translate('status_label'), _appConfig.translate('premium_member')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_appConfig.translate('close'))),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(String title, String desc, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: _appConfig.isDarkMode ? Colors.white : AppColors.black))),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: GoogleFonts.outfit(fontSize: 13, color: _appConfig.isDarkMode ? Colors.white70 : AppColors.grey, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _appConfig.isDarkMode ? Colors.white : AppColors.black)),
      ],
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _appConfig.isDarkMode ? const Color(0xFF111827) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_appConfig.translate('select_language'), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: _appConfig.isDarkMode ? Colors.white : AppColors.black)),
            const SizedBox(height: 24),
            _buildLangItem('English', 'en'),
            const Divider(),
            _buildLangItem('हिंदी (Hindi)', 'hi'),
          ],
        ),
      ),
    );
  }

  Widget _buildLangItem(String name, String code) {
    bool isSelected = _appConfig.locale.languageCode == code;
    return ListTile(
      onTap: () {
        _appConfig.setLocale(code);
        Navigator.pop(context);
      },
      title: Text(name, style: GoogleFonts.outfit(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: _appConfig.isDarkMode ? Colors.white : AppColors.black)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.accent) : null,
    );
  }

  void _showNotificationSettings() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_appConfig.translate('notification_updated')), behavior: SnackBarBehavior.floating));
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: _appConfig.isDarkMode ? const Color(0xFF1F2937) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(child: Text(_appConfig.translate('privacy_title'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _appConfig.isDarkMode ? Colors.white : AppColors.black))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_appConfig.translate('privacy_desc'), style: GoogleFonts.outfit(fontSize: 14, color: _appConfig.isDarkMode ? Colors.white70 : AppColors.grey, height: 1.5)),
              const SizedBox(height: 20),
              _buildInfoRow(_appConfig.translate('security_level'), _appConfig.translate('high')),
              const SizedBox(height: 20),
              _buildPrivacySection(_appConfig.translate('edge_processing'), _appConfig.translate('edge_processing_desc'), Icons.memory_rounded),
              _buildPrivacySection(_appConfig.translate('secure_integration'), _appConfig.translate('secure_integration_desc'), Icons.sync_lock_rounded),
              _buildPrivacySection(_appConfig.translate('transparent_governance'), _appConfig.translate('transparent_governance_desc'), Icons.gavel_rounded),
              _buildPrivacySection(_appConfig.translate('bank_grade_encryption'), _appConfig.translate('bank_grade_encryption_desc'), Icons.verified_user_rounded),
              _buildPrivacySection(_appConfig.translate('safety_guardrails'), _appConfig.translate('safety_guardrails_desc'), Icons.health_and_safety_rounded),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_appConfig.translate('close'))),
        ],
      ),
    );
  }

  void _showHelpSupport() {
    showAboutDialog(
      context: context,
      applicationName: 'NutriScan AI',
      applicationVersion: '1.0.2',
      applicationIcon: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 40),
      children: [
        Text('\n${_appConfig.translate('need_help')}\n'),
        Text(_appConfig.translate('ai_learning_text')),
      ],
    );
  }
}

class _ProfileItem {
  final IconData icon;
  final String label;
  final Color color;
  final String? trailing;
  final VoidCallback? onTap;

  _ProfileItem({required this.icon, required this.label, required this.color, this.trailing, this.onTap});
}

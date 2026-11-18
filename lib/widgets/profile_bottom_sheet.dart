import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pharmacy_profile.dart';
import '../providers/providers.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/url_launcher.dart';

void showProfileBottomSheet(
  BuildContext context,
  WidgetRef ref,
  PharmacyProfile? profile,
) {
  final colors = AppColors.of(context);
  final authUser = ref.read(authServiceProvider).currentUser;
  final loc = ref.read(pharmacyLocationFutureProvider).valueOrNull;

  final userEmail = (authUser?.email ?? profile?.email ?? '').trim();
  final docId = profile?.uid ?? loc?.docId ?? authUser?.uid ?? 'Not resolved';
  final pharmacyName = (profile?.pharmacyName ?? loc?.pharmacyName ?? 'My Pharmacy').trim();
  final handlerName = (profile?.handlerName ?? authUser?.displayName ?? 'Pharmacist').trim();
  final phone = (profile?.phone ?? '').trim();
  final address = (profile?.address ?? '').trim();
  final gstin = (profile?.gstin ?? '').trim();
  final area = (profile?.area ?? loc?.area ?? 'Selaqui').trim();
  final city = (profile?.city ?? loc?.city ?? 'Dehradun').trim();
  final radius = profile?.deliveryRadiusKm ?? 5.0;
  final hasLoc = profile?.hasLocation ?? false;
  bool isStoreOpen = profile?.isOpen ?? true;

  showModalBottomSheet(
    context: context,
    backgroundColor: colors.surfaceCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.surfaceLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ─── Header: Pharmacy Brand & Live Status ──────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceLight,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          AppAssets.appLogo,
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pharmacyName.isNotEmpty ? pharmacyName : 'Klinixy Pharmacy',
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Handler: $handlerName',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    hasLoc ? Icons.check_circle_rounded : Icons.location_off_rounded,
                                    size: 13,
                                    color: hasLoc ? AppColors.success : AppColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '$area, $city ${hasLoc ? "(GPS Set)" : "(No GPS)"}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: hasLoc ? AppColors.primary : AppColors.warning,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Store Status Switch Toggle
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isStoreOpen
                                    ? AppColors.success.withValues(alpha: 0.15)
                                    : AppColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isStoreOpen ? 'OPEN' : 'CLOSED',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isStoreOpen ? AppColors.success : AppColors.error,
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: 0.75,
                              child: Switch(
                                value: isStoreOpen,
                                activeThumbColor: AppColors.success,
                                onChanged: (newVal) async {
                                  setSheetState(() => isStoreOpen = newVal);
                                  try {
                                    final docPath = loc?.path ?? 'pharmacies/$docId';
                                    await ref.read(authServiceProvider).updatePharmacyProfile(
                                          docPath: docPath,
                                          pharmacyName: pharmacyName,
                                          handlerName: handlerName,
                                          isOpen: newVal,
                                          updatedByUid: authUser?.uid,
                                        );
                                  } catch (_) {}
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ─── Section: Account & Authentication Details ──────────────
                  _buildSectionLabel('ACCOUNT & CREDENTIALS', colors),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.surfaceLight, width: 1.2),
                    ),
                    child: Column(
                      children: [
                        // Email Row
                        _buildInfoTile(
                          icon: Icons.alternate_email_rounded,
                          label: 'Account Email (Logged In)',
                          value: userEmail.isNotEmpty ? userEmail : 'No email associated',
                          colors: colors,
                          trailing: userEmail.isNotEmpty
                              ? _buildCopyButton(context, userEmail, 'Email copied to clipboard!')
                              : null,
                        ),
                        Divider(height: 1, indent: 48, color: colors.surfaceLight),

                        // Store ID / Doc ID Row
                        _buildInfoTile(
                          icon: Icons.badge_outlined,
                          label: 'Store Document ID',
                          value: docId,
                          colors: colors,
                          trailing: _buildCopyButton(context, docId, 'Store ID copied to clipboard!'),
                        ),
                        Divider(height: 1, indent: 48, color: colors.surfaceLight),

                        // Phone Number Row
                        _buildInfoTile(
                          icon: Icons.phone_outlined,
                          label: 'Phone Number',
                          value: phone.isNotEmpty ? phone : 'Not configured (Tap Edit)',
                          colors: colors,
                          trailing: phone.isNotEmpty
                              ? _buildCopyButton(context, phone, 'Phone copied!')
                              : null,
                        ),
                        Divider(height: 1, indent: 48, color: colors.surfaceLight),

                        // GSTIN Row
                        _buildInfoTile(
                          icon: Icons.receipt_long_outlined,
                          label: 'GSTIN Registration',
                          value: gstin.isNotEmpty ? gstin : 'Not registered (Tap Edit)',
                          colors: colors,
                          trailing: gstin.isNotEmpty
                              ? _buildCopyButton(context, gstin, 'GSTIN copied!')
                              : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ─── Section: Store Location & Quick-Commerce Reach ─────────
                  _buildSectionLabel('STORE LOCATION & DELIVERY REACH', colors),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.surfaceLight, width: 1.2),
                    ),
                    child: Column(
                      children: [
                        // Full Address Row
                        _buildInfoTile(
                          icon: Icons.storefront_outlined,
                          label: 'Physical Address',
                          value: address.isNotEmpty ? address : '$area, $city',
                          colors: colors,
                        ),
                        Divider(height: 1, indent: 48, color: colors.surfaceLight),

                        // Delivery Coverage Radius
                        _buildInfoTile(
                          icon: Icons.delivery_dining_outlined,
                          label: 'Quick-Commerce Delivery Radius',
                          value: '${radius.toStringAsFixed(1)} km delivery radius',
                          colors: colors,
                        ),
                        Divider(height: 1, indent: 48, color: colors.surfaceLight),

                        // GPS Coordinates Row
                        _buildInfoTile(
                          icon: Icons.pin_drop_outlined,
                          label: 'GPS Coordinates',
                          value: hasLoc
                              ? '${profile!.latitude!.toStringAsFixed(6)}, ${profile.longitude!.toStringAsFixed(6)}'
                              : 'Coordinates not set',
                          colors: colors,
                          trailing: hasLoc
                              ? TextButton.icon(
                                  onPressed: () {
                                    launchUrlString(
                                      'https://www.google.com/maps/search/?api=1&query=${profile!.latitude},${profile.longitude}',
                                    );
                                  },
                                  icon: const Icon(Icons.open_in_new, size: 14),
                                  label: const Text('Map'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Action Buttons ─────────────────────────────────────────
                  Row(
                    children: [
                      // Edit Profile & Location Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            showEditProfileDialog(context, ref, profile);
                          },
                          icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                          label: const Text('Edit Profile & Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Sign Out Button
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await ref.read(authServiceProvider).signOut();
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                        label: const Text('Log Out', style: TextStyle(color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildSectionLabel(String label, AppColors colors) {
  return Text(
    label,
    style: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: colors.textSecondary,
    ),
  );
}

Widget _buildInfoTile({
  required IconData icon,
  required String label,
  required String value,
  required AppColors colors,
  Widget? trailing,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );
}

Widget _buildCopyButton(BuildContext context, String textToCopy, String message) {
  return IconButton(
    icon: const Icon(Icons.copy_rounded, size: 16),
    color: AppColors.primary,
    tooltip: 'Copy to clipboard',
    visualDensity: VisualDensity.compact,
    onPressed: () {
      Clipboard.setData(ClipboardData(text: textToCopy));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.primary,
        ),
      );
    },
  );
}

void showEditProfileDialog(
  BuildContext context,
  WidgetRef ref,
  PharmacyProfile? profile,
) {
  final colors = AppColors.of(context);
  final authUser = ref.read(authServiceProvider).currentUser;
  final loc = ref.read(pharmacyLocationFutureProvider).valueOrNull;
  final formKey = GlobalKey<FormState>();

  final userEmail = (authUser?.email ?? profile?.email ?? '').trim();
  final docId = profile?.uid ?? loc?.docId ?? authUser?.uid ?? '';

  final nameCtrl = TextEditingController(text: profile?.pharmacyName ?? loc?.pharmacyName ?? '');
  final handlerCtrl = TextEditingController(text: profile?.handlerName ?? '');
  final emailCtrl = TextEditingController(text: profile?.email ?? userEmail);
  final phoneCtrl = TextEditingController(text: profile?.phone ?? '');
  final addressCtrl = TextEditingController(text: profile?.address ?? '');
  final gstinCtrl = TextEditingController(text: profile?.gstin ?? '');
  final radiusCtrl = TextEditingController(text: (profile?.deliveryRadiusKm ?? 5.0).toString());

  final latCtrl = TextEditingController(
      text: profile?.latitude != null ? profile!.latitude!.toStringAsFixed(6) : '');
  final lngCtrl = TextEditingController(
      text: profile?.longitude != null ? profile!.longitude!.toStringAsFixed(6) : '');

  bool isOpen = profile?.isOpen ?? true;
  bool isDetectingGps = false;
  bool isSaving = false;

  showDialog(
    context: context,
    builder: (dlgContext) {
      return StatefulBuilder(
        builder: (context, setDlgState) {
          final lat = double.tryParse(latCtrl.text.trim());
          final lng = double.tryParse(lngCtrl.text.trim());
          final hasValidCoords = lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

          return AlertDialog(
            backgroundColor: colors.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Edit Pharmacy Profile',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Account & Credentials Header Banner ───────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.surfaceLight),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Logged in as: $userEmail',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Store Doc: $docId',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: colors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Store Active Status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isOpen ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                              color: isOpen ? AppColors.success : AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isOpen ? 'Store is OPEN' : 'Store is CLOSED',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isOpen ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                  Text(
                                    isOpen
                                        ? 'Visible on Klinixy customer app for instant orders'
                                        : 'Orders temporarily paused for customers',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isOpen,
                              activeThumbColor: AppColors.success,
                              onChanged: (val) => setDlgState(() => isOpen = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pharmacy Name
                      _buildTextField(
                        controller: nameCtrl,
                        label: 'Pharmacy Name *',
                        icon: Icons.local_pharmacy_rounded,
                        colors: colors,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Pharmacy name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Handler Name
                      _buildTextField(
                        controller: handlerCtrl,
                        label: 'Pharmacist / Handler Name *',
                        icon: Icons.person_rounded,
                        colors: colors,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Handler name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Contact Email
                      _buildTextField(
                        controller: emailCtrl,
                        label: 'Contact / Notification Email',
                        icon: Icons.email_outlined,
                        colors: colors,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),

                      // Phone Number
                      _buildTextField(
                        controller: phoneCtrl,
                        label: 'Pharmacy Phone Number',
                        icon: Icons.phone_rounded,
                        colors: colors,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),

                      // GSTIN
                      _buildTextField(
                        controller: gstinCtrl,
                        label: 'GSTIN Registration Number',
                        icon: Icons.receipt_long_rounded,
                        colors: colors,
                      ),
                      const SizedBox(height: 12),

                      // Delivery Radius
                      _buildTextField(
                        controller: radiusCtrl,
                        label: 'Delivery Radius (km)',
                        icon: Icons.delivery_dining_rounded,
                        colors: colors,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Enter a valid radius (e.g. 5.0)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Physical Store Address
                      _buildTextField(
                        controller: addressCtrl,
                        label: 'Store Physical Address',
                        icon: Icons.location_on_rounded,
                        colors: colors,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // ─── GPS Coordinates Section ─────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasValidCoords
                                ? AppColors.success.withValues(alpha: 0.3)
                                : AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  hasValidCoords ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                                  color: hasValidCoords ? AppColors.success : AppColors.warning,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'GPS Coordinates (Klinixy Rider Pickup)',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                if (hasValidCoords)
                                  InkWell(
                                    onTap: () {
                                      launchUrlString(
                                        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        Text('View', style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.open_in_new, size: 12, color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCoordField(
                                    controller: latCtrl,
                                    label: 'Latitude',
                                    colors: colors,
                                    onChanged: (_) => setDlgState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildCoordField(
                                    controller: lngCtrl,
                                    label: 'Longitude',
                                    colors: colors,
                                    onChanged: (_) => setDlgState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: isDetectingGps
                                    ? null
                                    : () async {
                                        setDlgState(() => isDetectingGps = true);
                                        try {
                                          LocationPermission perm = await Geolocator.checkPermission();
                                          if (perm == LocationPermission.denied) {
                                            perm = await Geolocator.requestPermission();
                                          }
                                          if (perm == LocationPermission.deniedForever) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Location permission is denied forever. Enter coordinates manually.'),
                                                  backgroundColor: AppColors.error,
                                                ),
                                              );
                                            }
                                            return;
                                          }

                                          final pos = await Geolocator.getCurrentPosition(
                                            locationSettings: const LocationSettings(
                                              accuracy: LocationAccuracy.high,
                                            ),
                                          );
                                          latCtrl.text = pos.latitude.toStringAsFixed(6);
                                          lngCtrl.text = pos.longitude.toStringAsFixed(6);
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Could not detect location: $e'),
                                                backgroundColor: AppColors.error,
                                              ),
                                            );
                                          }
                                        } finally {
                                          setDlgState(() => isDetectingGps = false);
                                        }
                                      },
                                icon: isDetectingGps
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.my_location_rounded, size: 16),
                                label: Text(
                                  isDetectingGps ? 'Detecting GPS...' : 'Use Current Device GPS',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dlgContext),
                child: Text('Cancel', style: GoogleFonts.inter(color: colors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final authUser = ref.read(authServiceProvider).currentUser;
                        final loc = ref.read(pharmacyLocationFutureProvider).valueOrNull;
                        final docId = profile?.uid ?? loc?.docId ?? authUser?.uid;
                        if (docId == null || docId.isEmpty) return;

                        setDlgState(() => isSaving = true);
                        try {
                          final docPath = loc?.path ?? 'pharmacies/$docId';

                          GeoPoint? geoPoint;
                          final parsedLat = double.tryParse(latCtrl.text.trim());
                          final parsedLng = double.tryParse(lngCtrl.text.trim());
                          if (parsedLat != null && parsedLng != null) {
                            geoPoint = GeoPoint(parsedLat, parsedLng);
                          }

                          await ref.read(authServiceProvider).updatePharmacyProfile(
                                docPath: docPath,
                                pharmacyName: nameCtrl.text.trim(),
                                handlerName: handlerCtrl.text.trim(),
                                location: geoPoint,
                                address: addressCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                isOpen: isOpen,
                                deliveryRadiusKm: double.tryParse(radiusCtrl.text.trim()) ?? 5.0,
                                gstin: gstinCtrl.text.trim(),
                                updatedByUid: authUser?.uid,
                              );

                          if (dlgContext.mounted) {
                            Navigator.pop(dlgContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pharmacy profile & location updated successfully!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (dlgContext.mounted) {
                            setDlgState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Save Changes', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  required AppColors colors,
  int maxLines = 1,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    validator: validator,
    style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
      prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
      filled: true,
      fillColor: colors.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
  );
}

Widget _buildCoordField({
  required TextEditingController controller,
  required String label,
  required AppColors colors,
  required ValueChanged<String> onChanged,
}) {
  return TextFormField(
    controller: controller,
    onChanged: onChanged,
    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
    style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
      filled: true,
      fillColor: colors.surfaceCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.surfaceLight),
      ),
    ),
  );
}

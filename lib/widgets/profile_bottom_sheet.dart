import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  showModalBottomSheet(
    context: context,
    backgroundColor: colors.surfaceCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final hasLoc = profile?.hasLocation ?? false;
      final isOpen = profile?.isOpen ?? true;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colors.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: AppColors.accentGradient),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              profile?.pharmacyName ?? 'My Pharmacy',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOpen
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOpen ? 'OPEN' : 'CLOSED',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isOpen ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Handler: ${profile?.handlerName ?? 'Pharmacist'}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            hasLoc ? Icons.location_on : Icons.location_off_outlined,
                            size: 13,
                            color: hasLoc ? AppColors.primary : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hasLoc
                                  ? '${profile!.area}, ${profile.city} (GPS Set)'
                                  : '${profile?.area ?? "Selaqui"}, ${profile?.city ?? "Dehradun"} (Location Not Set)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: hasLoc ? AppColors.primary : AppColors.warning,
                                fontWeight: FontWeight.w500,
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
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Edit Profile & Location Option
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_location_alt_outlined,
                    color: AppColors.primary, size: 20),
              ),
              title: Text(
                'Edit Profile & Location',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Update GPS coordinates, address, phone & store status',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () {
                Navigator.pop(ctx);
                showEditProfileDialog(context, ref, profile);
              },
            ),

            const SizedBox(height: 8),

            // Logout Option
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: AppColors.error, size: 20),
              ),
              title: Text(
                'Log Out',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              subtitle: Text(
                'Sign out of your pharmacy session',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(authServiceProvider).signOut();
              },
            ),
            const SizedBox(height: 16),
          ],
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
  final formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController(text: profile?.pharmacyName ?? '');
  final handlerCtrl = TextEditingController(text: profile?.handlerName ?? '');
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
                  'Edit Pharmacy & Location',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    isOpen ? 'Accepting online & walk-in orders' : 'Paused for orders',
                                    style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isOpen,
                              activeThumbColor: AppColors.success,
                              onChanged: (v) => setDlgState(() => isOpen = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Basic Details
                      Text(
                        'BASIC DETAILS',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: nameCtrl,
                        style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.local_pharmacy_outlined, size: 20),
                          labelText: 'Pharmacy Name *',
                          isDense: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: handlerCtrl,
                              style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.person_outline, size: 20),
                                labelText: 'Handler Name *',
                                isDense: true,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.phone_outlined, size: 20),
                                labelText: 'Contact Phone',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: addressCtrl,
                        style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.home_work_outlined, size: 20),
                          labelText: 'Full Street Address & Landmark',
                          hintText: 'e.g. Shop 12, Main Bazar, Selaqui',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: gstinCtrl,
                              style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.badge_outlined, size: 20),
                                labelText: 'GSTIN',
                                hintText: 'e.g. 27AABCP1234F1Z5',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: radiusCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.near_me_outlined, size: 20),
                                labelText: 'Delivery Radius (km)',
                                hintText: '5.0',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Location & GPS section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'GPS LOCATION & COORDINATES',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: colors.textSecondary,
                            ),
                          ),
                          if (hasValidCoords)
                            TextButton.icon(
                              onPressed: () {
                                final url = 'https://www.google.com/maps?q=$lat,$lng';
                                launchUrlString(url);
                              },
                              icon: const Icon(Icons.map_outlined, size: 14, color: AppColors.primary),
                              label: Text('Open Maps',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary)),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasValidCoords
                                ? AppColors.success.withValues(alpha: 0.3)
                                : AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isDetectingGps
                                        ? null
                                        : () async {
                                            setDlgState(() => isDetectingGps = true);
                                            try {
                                              bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                              if (!serviceEnabled) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Please enable GPS / Location Services on your device.'),
                                                      backgroundColor: AppColors.warning,
                                                    ),
                                                  );
                                                }
                                                setDlgState(() => isDetectingGps = false);
                                                return;
                                              }

                                              LocationPermission permission = await Geolocator.checkPermission();
                                              if (permission == LocationPermission.denied) {
                                                permission = await Geolocator.requestPermission();
                                                if (permission == LocationPermission.denied) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Location permission denied. You can still enter coordinates manually.'),
                                                        backgroundColor: AppColors.warning,
                                                      ),
                                                    );
                                                  }
                                                  setDlgState(() => isDetectingGps = false);
                                                  return;
                                                }
                                              }

                                              if (permission == LocationPermission.deniedForever) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Location permissions are permanently denied. Please allow location in browser/system settings or enter manually.'),
                                                      backgroundColor: AppColors.error,
                                                    ),
                                                  );
                                                }
                                                setDlgState(() => isDetectingGps = false);
                                                return;
                                              }

                                              final pos = await Geolocator.getCurrentPosition(
                                                locationSettings: const LocationSettings(
                                                  accuracy: LocationAccuracy.high,
                                                ),
                                              );

                                              latCtrl.text = pos.latitude.toStringAsFixed(6);
                                              lngCtrl.text = pos.longitude.toStringAsFixed(6);

                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Location acquired: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}'),
                                                    backgroundColor: AppColors.success,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Could not fetch GPS location: $e'),
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
                                      isDetectingGps ? 'Detecting GPS...' : 'Use Current Location',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      side: const BorderSide(color: AppColors.primary),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: latCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                    style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary),
                                    decoration: const InputDecoration(
                                      labelText: 'Latitude',
                                      hintText: 'e.g. 30.3643',
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setDlgState(() {}),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return null;
                                      final n = double.tryParse(v.trim());
                                      if (n == null || n < -90 || n > 90) return '-90 to 90';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: lngCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                    style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary),
                                    decoration: const InputDecoration(
                                      labelText: 'Longitude',
                                      hintText: 'e.g. 77.8541',
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setDlgState(() {}),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return null;
                                      final n = double.tryParse(v.trim());
                                      if (n == null || n < -180 || n > 180) return '-180 to 180';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
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

                          final authUser = ref.read(authServiceProvider).currentUser;

                          await ref.read(authServiceProvider).updatePharmacyProfile(
                                docPath: docPath,
                                pharmacyName: nameCtrl.text.trim(),
                                handlerName: handlerCtrl.text.trim(),
                                location: geoPoint,
                                address: addressCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
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

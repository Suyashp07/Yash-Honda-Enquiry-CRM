import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/api_constants.dart';

/// Resolves relative backend asset paths (like `/api/uploads/...`) safely.
String resolveBackendAssetUrl(String url) {
  final clean = url.trim();
  if (clean.startsWith('http://') ||
      clean.startsWith('https://') ||
      clean.startsWith('data:image')) {
    return clean;
  }
  final base = ApiConstants.baseUrl.endsWith('/api')
      ? ApiConstants.baseUrl.substring(0, ApiConstants.baseUrl.length - 4)
      : ApiConstants.baseUrl;
  return '$base${clean.startsWith('/') ? '' : '/'}$clean';
}

/// Renders Base64 Data URIs, remote network images, or bundled Flutter assets safely.
class SmartMediaImage extends StatelessWidget {
  final String? source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? fallback;

  const SmartMediaImage({
    super.key,
    required this.source,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.fallback,
  });

  static final Map<int, Uint8List> _decodedCache = {};

  Uint8List? _decodeDataUri(String dataUri) {
    final key = dataUri.hashCode;
    if (_decodedCache.containsKey(key)) return _decodedCache[key];
    try {
      final commaIdx = dataUri.indexOf(',');
      final payload =
          commaIdx != -1 ? dataUri.substring(commaIdx + 1) : dataUri;
      final bytes = base64Decode(payload);
      if (_decodedCache.length > 60) {
        _decodedCache.clear();
      }
      _decodedCache[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultFallback = fallback ??
        const Center(
          child: Icon(Icons.two_wheeler_outlined,
              size: 40, color: Color(0xFFCBD5E1)),
        );

    final src = source?.trim() ?? '';
    if (src.isEmpty) return defaultFallback;

    if (src.startsWith('data:image')) {
      final bytes = _decodeDataUri(src);
      if (bytes == null) return defaultFallback;
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => defaultFallback,
      );
    }

    if (src.startsWith('assets/')) {
      final cleanPath = src.replaceFirst('assets/', '');
      return Image.asset(
        src,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => Image.network(
          'assets/$cleanPath',
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => Image.network(
            'assets/assets/$cleanPath',
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, __, ___) => defaultFallback,
          ),
        ),
      );
    }

    return Image.network(
      resolveBackendAssetUrl(src),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => defaultFallback,
    );
  }
}

class LocalImageInspectResult {
  final Uint8List bytes;
  final String filename;
  final int width;
  final int height;
  final String qualityStatus; // 'excellent' | 'acceptable' | 'rejected'
  final String message;

  const LocalImageInspectResult({
    required this.bytes,
    required this.filename,
    required this.width,
    required this.height,
    required this.qualityStatus,
    required this.message,
  });
}

/// Picks an image file and measures exact pixel dimensions client-side before upload.
Future<LocalImageInspectResult?> pickAndInspectImage({
  required bool isAccessory,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    withData: true,
  );

  if (result == null || result.files.isEmpty) return null;
  final picked = result.files.single;
  final bytes = picked.bytes;
  if (bytes == null || bytes.isEmpty) {
    return LocalImageInspectResult(
      bytes: Uint8List(0),
      filename: picked.name,
      width: 0,
      height: 0,
      qualityStatus: 'rejected',
      message: 'Could not read image bytes from selected file.',
    );
  }

  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width;
    final h = frame.image.height;
    frame.image.dispose();
    codec.dispose();

    final shortest = w < h ? w : h;
    final totalPx = w * h;
    final minShort = isAccessory ? 200 : 420;
    final recShort = isAccessory ? 400 : 600;
    final minTotal = isAccessory ? 40000 : 240000;

    if (shortest < minShort || totalPx < minTotal) {
      return LocalImageInspectResult(
        bytes: bytes,
        filename: picked.name,
        width: w,
        height: h,
        qualityStatus: 'rejected',
        message:
            'Image too small ($w×$h px). Minimum ${minShort}px short side required so it does not look blurry.',
      );
    }

    final ratio = w / h;
    if (ratio < 0.45 || ratio > 2.5) {
      return LocalImageInspectResult(
        bytes: bytes,
        filename: picked.name,
        width: w,
        height: h,
        qualityStatus: 'rejected',
        message:
            'Aspect ratio (${ratio.toStringAsFixed(2)}:1) is too stretched or narrow ($w×$h px). Use a clean studio shot.',
      );
    }

    if (shortest < recShort) {
      return LocalImageInspectResult(
        bytes: bytes,
        filename: picked.name,
        width: w,
        height: h,
        qualityStatus: 'acceptable',
        message:
            '$w×$h px — Acceptable quality (${recShort}px+ recommended for best tablet clarity).',
      );
    }

    return LocalImageInspectResult(
      bytes: bytes,
      filename: picked.name,
      width: w,
      height: h,
      qualityStatus: 'excellent',
      message: '$w×$h px — Sharp HD quality, fits designer frames cleanly.',
    );
  } catch (e) {
    return LocalImageInspectResult(
      bytes: Uint8List(0),
      filename: picked.name,
      width: 0,
      height: 0,
      qualityStatus: 'rejected',
      message: 'Unsupported or corrupted image file ($e).',
    );
  }
}

/// Interactive Media & Per-Colour Image Manager for a Vehicle Master.
Future<void> showVehicleMediaManagerDialog({
  required BuildContext context,
  required Dio dio,
  required Map<String, dynamic> vehicle,
  required VoidCallback onUpdated,
}) async {
  Map<String, dynamic> workingVehicle = Map<String, dynamic>.from(vehicle);
  String? activeSlotBusy;
  String? statusFeedback;
  bool statusIsError = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDlgState) {
        final vId = workingVehicle['id'].toString();
        final vName = workingVehicle['name'] ?? workingVehicle['code'] ?? 'Model';
        final listingUrl = workingVehicle['listingImageUrl']?.toString();
        final detailUrl = workingVehicle['detailImageUrl']?.toString();
        final colours = (workingVehicle['colours'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        Future<void> handleUpload(String endpoint, String busyKey) async {
          final inspect = await pickAndInspectImage(isAccessory: false);
          if (inspect == null) return;

          if (inspect.qualityStatus == 'rejected') {
            setDlgState(() {
              statusFeedback = inspect.message;
              statusIsError = true;
            });
            return;
          }

          setDlgState(() {
            activeSlotBusy = busyKey;
            statusFeedback = null;
          });

          try {
            final formData = FormData.fromMap({
              'file': MultipartFile.fromBytes(
                inspect.bytes,
                filename: inspect.filename,
              ),
            });
            final res = await dio.post(endpoint, data: formData);
            if (res.data?['vehicle'] != null) {
              workingVehicle =
                  Map<String, dynamic>.from(res.data['vehicle'] as Map);
            }
            final q = res.data?['quality'];
            final sizeInfo = q != null
                ? 'Normalized to ${q['width']}×${q['height']} WebP (${q['sizeKb']} KB)'
                : inspect.message;

            setDlgState(() {
              activeSlotBusy = null;
              statusFeedback = 'Saved! $sizeInfo';
              statusIsError = false;
            });
            onUpdated();
          } catch (e) {
            String errMsg = 'Upload failed: $e';
            if (e is DioException && e.response?.data != null) {
              errMsg = e.response?.data['message']?.toString() ?? errMsg;
            }
            setDlgState(() {
              activeSlotBusy = null;
              statusFeedback = errMsg;
              statusIsError = true;
            });
          }
        }

        Future<void> handleDelete(String endpoint, String busyKey) async {
          setDlgState(() {
            activeSlotBusy = busyKey;
            statusFeedback = null;
          });
          try {
            final res = await dio.delete(endpoint);
            if (res.data?['vehicle'] != null) {
              workingVehicle =
                  Map<String, dynamic>.from(res.data['vehicle'] as Map);
            }
            setDlgState(() {
              activeSlotBusy = null;
              statusFeedback = 'Image removed.';
              statusIsError = false;
            });
            onUpdated();
          } catch (e) {
            setDlgState(() {
              activeSlotBusy = null;
              statusFeedback = 'Could not remove image: $e';
              statusIsError = true;
            });
          }
        }

        Color parseHex(String? raw) {
          try {
            var c = (raw ?? '#111827').replaceAll('#', '');
            if (c.length == 6) c = 'FF$c';
            return Color(int.parse(c, radix: 16));
          } catch (_) {
            return const Color(0xFF111827);
          }
        }

        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_outlined,
                    color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle & Colour Images · $vName',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Color(0xFF0F172A)),
                    ),
                    const Text(
                      'Sharp auto-validates resolution (min 420px short side) & converts to crisp WebP.',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SizedBox(
            width: 780,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (statusFeedback != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: statusIsError
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: statusIsError
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFF86EFAC),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            statusIsError
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            size: 18,
                            color: statusIsError
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              statusFeedback!,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: statusIsError
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFF166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Row 1: Primary Listing Card Image + Primary Studio Detail Image
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _MediaSlotPreviewCard(
                          title: 'Step 2 Listing Card Image',
                          subtitle:
                              'Shown on category vehicle cards (recommended 800×600+ px).',
                          imageUrl: listingUrl,
                          aspectRatio: 4 / 3,
                          previewFit: BoxFit.cover,
                          isBusy: activeSlotBusy == 'listing',
                          onUpload: () => handleUpload(
                              '/vehicles/$vId/images/listing', 'listing'),
                          onRemove: listingUrl != null && listingUrl.isNotEmpty
                              ? () => handleDelete(
                                  '/vehicles/$vId/images/listing', 'listing')
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _MediaSlotPreviewCard(
                          title: 'Default Studio Showcase (Steps 3–7)',
                          subtitle:
                              'Large side-profile studio image on pure white (1000×800+ px transparent PNG or white studio shot).',
                          imageUrl: detailUrl,
                          aspectRatio: 4 / 3,
                          previewFit: BoxFit.contain,
                          isBusy: activeSlotBusy == 'detail',
                          onUpload: () => handleUpload(
                              '/vehicles/$vId/images/detail', 'detail'),
                          onRemove: detailUrl != null && detailUrl.isNotEmpty
                              ? () => handleDelete(
                                  '/vehicles/$vId/images/detail', 'detail')
                              : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),
                  const Text(
                    'Per-Colour Showroom Images (Step 3 Swatch Swap)',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Assign specific vehicle photos for each colour so tapping a colour dot updates the bike visually.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),

                  if (colours.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'No factory colours are assigned to this model yet. Edit the vehicle to select available colours first.',
                        style:
                            TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: colours.map((vc) {
                        final col = vc['colour'] as Map? ?? {};
                        final cid = col['id']?.toString() ?? vc['colourId']?.toString() ?? '';
                        final cName = col['name']?.toString() ?? 'Colour';
                        final hex = col['hex']?.toString();
                        final cImgUrl = vc['colourImageUrl']?.toString();
                        final busyKey = 'colour-$cid';

                        return Container(
                          width: 248,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: parseHex(hex),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              AspectRatio(
                                aspectRatio: 4 / 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: activeSlotBusy == busyKey
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFFDC2626)),
                                        )
                                      : SmartMediaImage(
                                          source: cImgUrl,
                                          fit: BoxFit.contain,
                                          fallback: const Center(
                                            child: Text(
                                              'Uses default',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF94A3B8)),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        side: const BorderSide(
                                            color: Color(0xFFCBD5E1)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      onPressed: activeSlotBusy != null
                                          ? null
                                          : () => handleUpload(
                                              '/vehicles/$vId/colours/$cid/image',
                                              busyKey),
                                      icon: const Icon(Icons.upload_rounded,
                                          size: 14, color: Color(0xFF334155)),
                                      label: Text(
                                        cImgUrl != null && cImgUrl.isNotEmpty
                                            ? 'Replace'
                                            : 'Upload',
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF334155)),
                                      ),
                                    ),
                                  ),
                                  if (cImgUrl != null && cImgUrl.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 16, color: Color(0xFFDC2626)),
                                      tooltip: 'Clear colour image',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(6),
                                      onPressed: activeSlotBusy != null
                                          ? null
                                          : () => handleDelete(
                                              '/vehicles/$vId/colours/$cid/image',
                                              busyKey),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        );
      },
    ),
  );
}

class _MediaSlotPreviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final double aspectRatio;
  final BoxFit previewFit;
  final bool isBusy;
  final VoidCallback onUpload;
  final VoidCallback? onRemove;

  const _MediaSlotPreviewCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.aspectRatio,
    required this.previewFit,
    required this.isBusy,
    required this.onUpload,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: isBusy
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFDC2626)),
                    )
                  : SmartMediaImage(
                      source: imageUrl,
                      fit: previewFit,
                      fallback: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 32, color: Color(0xFFCBD5E1)),
                            SizedBox(height: 6),
                            Text(
                              'No image uploaded\n(Uses fallback artwork)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isBusy ? null : onUpload,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                  label: Text(
                    hasImage ? 'Replace Photo' : 'Upload Photo',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isBusy ? null : onRemove,
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: Color(0xFFDC2626)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:microsensors/features/components/smart_image/smart_image.dart';
import 'package:microsensors/utils/colors.dart';

class PhotoViewerPage extends HookWidget {
  final String imageUrl;
  final String? baseUrl;
  final String? title;

  const PhotoViewerPage({
    super.key,
    required this.imageUrl,
    this.baseUrl,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = useState(false);

    /// ✅ Use SmartImage’s normalization logic directly
    String normalizeUrl(String? raw) {
      if (raw == null) return '';
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return '';

      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }

      if (baseUrl != null && baseUrl!.isNotEmpty) {
        final base = baseUrl!.endsWith('/')
            ? baseUrl!.substring(0, baseUrl!.length - 1)
            : baseUrl!;
        final path = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
        return '$base/$path';
      }

      return trimmed;
    }

    final fullUrl = normalizeUrl(imageUrl);

    Future<void> downloadImage() async {
      try {
        isDownloading.value = true;
        final dio = Dio();

        debugPrint('🧠 Downloading from: $fullUrl');

        // ✅ Check if URL is valid
        if (!fullUrl.startsWith('http')) {
          throw Exception('Invalid image URL: $fullUrl');
        }

        // ✅ Check for 200 OK before downloading
        final headResponse = await dio.head(fullUrl);
        if (headResponse.statusCode != 200) {
          throw Exception('Image not found (status: ${headResponse.statusCode})');
        }

        final Directory tempDir = await getTemporaryDirectory();
        final filePath =
            '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

        await dio.download(fullUrl, filePath);

        final bytes = await File(filePath).readAsBytes();
        final result = await ImageGallerySaverPlus.saveImage(
          Uint8List.fromList(bytes),
          quality: 100,
          name: p.basename(filePath),
          isReturnImagePathOfIOS: true,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                (result != null && result['isSuccess'] == true)
                    ? '✅ Image saved to gallery!'
                    : '❌ Failed to save image!',
              ),
              backgroundColor: (result != null && result['isSuccess'] == true)
                  ? Colors.green
                  : Colors.red,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Download error: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Download error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        isDownloading.value = false;
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title ?? 'Preview',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: isDownloading.value
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.download, color: Colors.white),
            onPressed: isDownloading.value ? null : downloadImage,
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: fullUrl,
          child: PhotoView.customChild(
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            child: SmartImage(
              imageUrl: imageUrl,
              baseUrl: baseUrl,
              width: double.infinity,
              height: double.infinity,
              shape: ImageShape.rounded,
              borderRadius: 20,
              fit: BoxFit.contain,
              useCached: true,
            ),
          ),
        ),
      ),
    );
  }
}

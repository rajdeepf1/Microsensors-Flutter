import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

/// A reusable widget that allows selecting an image from camera/gallery
/// and returns a Dio MultipartFile to the parent.
class ImagePickerField extends HookWidget {
  final Function(MultipartFile?) onImageSelected;
  final String? initialImageUrl; // optional for edit mode
  final double height;

  const ImagePickerField({
    super.key,
    required this.onImageSelected,
    this.initialImageUrl,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final picker = useMemoized(() => ImagePicker());
    final imageFile = useState<XFile?>(null);

    Future<void> pickImage(ImageSource source) async {
      try {
        final file = await picker.pickImage(
          source: source,
          imageQuality: 85,
        );
        if (file != null) {
          imageFile.value = file;
          final multipart = await MultipartFile.fromFile(
            file.path,
            filename: file.name,
          );
          onImageSelected(multipart);
        }
      } catch (e) {
        debugPrint('Image picking failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }

    void removeImage() {
      imageFile.value = null;
      onImageSelected(null);
    }

    return Column(
      children: [
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade100,
          ),
          child: Builder(
            builder: (context) {
              if (imageFile.value != null) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(imageFile.value!.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: removeImage,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                );
              } else if (initialImageUrl != null &&
                  initialImageUrl!.isNotEmpty) {
                // For edit mode (existing image)
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        initialImageUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: removeImage,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // No image selected
                return Center(
                  child: Text(
                    'Tap below to pick image',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
              onPressed: () => pickImage(ImageSource.gallery),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Camera'),
              onPressed: () => pickImage(ImageSource.camera),
            ),
          ],
        ),
      ],
    );
  }
}

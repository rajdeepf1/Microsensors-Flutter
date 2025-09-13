import 'package:flutter/material.dart';

import '../../../utils/constants.dart';
import '../smart_image/smart_image.dart';

class ProfilePic extends StatelessWidget {
  const ProfilePic({
    super.key,
    required this.image,
    required this.userName,
    this.isShowPhotoUpload = false,
    this.imageUploadBtnPress,
    this.placeHolder
  });

  final String image;
  final String userName;
  final bool isShowPhotoUpload;
  final VoidCallback? imageUploadBtnPress;
  final Widget? placeHolder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color:
          Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.08),
        ),
      ),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          SmartImage(
            imageUrl: image,
            baseUrl: Constants.apiBaseUrl,
            width: 120,
            height: 120,
            shape: ImageShape.circle,
            username: userName,
            placeholder: placeHolder,
          ),
          InkWell(
            onTap: imageUploadBtnPress,
            child: CircleAvatar(
              radius: 13,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 20,
              ),
            ),
          )
        ],
      ),
    );
  }
}

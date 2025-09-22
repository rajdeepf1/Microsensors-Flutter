import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/models/user_model/user_model.dart';

import '../../../utils/colors.dart';
import '../../../utils/constants.dart';
import '../smart_image/smart_image.dart';

class SearchUserDropdown extends HookWidget {
  final Future<List<UserDataModel>> Function(String query) searchFn;
  final void Function(UserDataModel user) onUserSelected;
  final String? hintText;

  /// Maximum height you want the overlay to be (it will be reduced if insufficient space)
  final double maxOverlayHeight;

  /// Show suggestions immediately when field gains focus (calls searchFn with empty string)
  final bool showAllOnFocus;

  /// Debounce duration
  final Duration debounceDuration;

  const SearchUserDropdown({
    Key? key,
    required this.searchFn,
    required this.onUserSelected,
    this.hintText,
    this.maxOverlayHeight = 240,
    this.showAllOnFocus = true,
    this.debounceDuration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController();
    final focusNode = useFocusNode();
    final layerLink = useMemoized(() => LayerLink());
    final overlayEntryRef = useRef<OverlayEntry?>(null);
    final debounceRef = useRef<Timer?>(null);

    final suggestions = useState<List<UserDataModel>>([]);
    final isLoading = useState<bool>(false);

    final isOverlayOpen = useState<bool>(false);
    final switchDuration = const Duration(milliseconds: 250);

    // Creates overlay with dynamic height and direction (up/down)
    OverlayEntry createOverlay(double availableAbove, double availableBelow, RenderBox box, bool showAbove) {
      final size = box.size;
      // Desired height = min(maxOverlayHeight, whichever available space chosen)
      final chosenSpace = showAbove ? availableAbove : availableBelow;
      final height = min(maxOverlayHeight, max(0.0, chosenSpace - 8.0)); // small margin
      final offset = showAbove ? Offset(0, -height - 4.0) : Offset(0, size.height + 4.0);

      return OverlayEntry(
        builder: (ctx) => Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: layerLink,
            showWhenUnlinked: false,
            offset: offset,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: height),
                child: isLoading.value
                    ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Center(
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                )
                    : suggestions.value.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text('No users', style: TextStyle(color: Colors.grey[600])),
                )
                    : ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: suggestions.value.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = suggestions.value[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      leading:

                      SmartImage(imageUrl: user.userImage,baseUrl: Constants.apiBaseUrl,username: user.username,shape: ImageShape.circle,),

                      title: Text(user.username, style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(user.email, style: TextStyle(color: Colors.grey[600])),
                      onTap: () {
                        controller.text = user.username;
                        onUserSelected(user);
                        overlayEntryRef.value?.remove();
                        overlayEntryRef.value = null;
                        focusNode.unfocus();
                      },
                    );
                  },

                ),
              ),
            ),
          ),
        ),
      );
    }

    void openOverlay() {

      if (overlayEntryRef.value != null) return; // already open

      // find renderbox & available spaces
      final renderBox = context.findRenderObject() as RenderBox;
      final topLeftGlobal = renderBox.localToGlobal(Offset.zero);
      final screenSize = MediaQuery.of(context).size;
      final viewInsets = MediaQuery.of(context).viewInsets; // keyboard height in bottom
      final padding = MediaQuery.of(context).padding;

      // available below = space from bottom of the field to top of keyboard or screen bottom
      final availableBelow = screenSize.height - (topLeftGlobal.dy + renderBox.size.height) - viewInsets.bottom - padding.bottom;
      // available above = space from top of field to top padding (status bar)
      final availableAbove = topLeftGlobal.dy - padding.top;

      // decide showAbove if below is too small and above has more room
      final showAbove = availableBelow < maxOverlayHeight && availableAbove > availableBelow;

      overlayEntryRef.value = createOverlay(availableAbove, availableBelow, renderBox, showAbove);
      Overlay.of(context)!.insert(overlayEntryRef.value!);

      // update flag so AnimatedSwitcher shows the close icon
      isOverlayOpen.value = true;
    }

    void closeOverlay() {
      // overlayEntryRef.value?.remove();
      // overlayEntryRef.value = null;

      if (overlayEntryRef.value == null) {
        isOverlayOpen.value = false;
        return;
      }

      try {
        overlayEntryRef.value?.remove();
      } catch (e) {
        // ignore remove errors
      } finally {
        overlayEntryRef.value = null;
        // update flag so AnimatedSwitcher shows the search icon
        isOverlayOpen.value = false;
      }
    }

    void onTextChanged(String value) {
      debounceRef.value?.cancel();
      debounceRef.value = Timer(debounceDuration, () async {
        final q = value.trim();
        if (q.isEmpty && !showAllOnFocus) {
          suggestions.value = [];
          overlayEntryRef.value?.markNeedsBuild();
          return;
        }

        isLoading.value = true;
        // open overlay (will compute available space)
        openOverlay();

        try {
          final res = await searchFn(q);
          suggestions.value = res;
        } catch (e) {
          suggestions.value = [];
        } finally {
          isLoading.value = false;
          overlayEntryRef.value?.markNeedsBuild();
        }
      });
    }

    // focus listener: open overlay on focus (and optionally fetch all)
    useEffect(() {
      void listener() {
        if (focusNode.hasFocus) {
          if (showAllOnFocus) {
            // fetch all by empty query immediately (no debounce) and open overlay
            isLoading.value = true;
            openOverlay();
            searchFn('').then((res) {
              suggestions.value = res;
            }).catchError((_) {
              suggestions.value = [];
            }).whenComplete(() {
              isLoading.value = false;
              overlayEntryRef.value?.markNeedsBuild();
            });
          } else {
            if (controller.text.trim().isNotEmpty) {
              onTextChanged(controller.text);
            } else {
              openOverlay(); // still open the overlay even if empty (shows "No users")
            }
          }
        } else {
          // delay to allow taps on overlay list tiles
          Future.delayed(Duration(milliseconds: 120), closeOverlay);
        }
      }

      focusNode.addListener(listener);
      return () => focusNode.removeListener(listener);
    }, [focusNode, controller.text]);

    // cleanup on unmount
    useEffect(() {
      return () {
        debounceRef.value?.cancel();
        closeOverlay();
      };
    }, const []);

    return CompositedTransformTarget(
      link: layerLink,
      child: TextField(
        controller: controller,
        focusNode: focusNode,

        decoration:
        InputDecoration(
          filled: true,
          fillColor: AppColors.appBlueColor.withValues(alpha: 0.05),
          hint: Text(hintText!),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          border: const OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(50)),
          ),
          hintStyle: TextStyle(color: Colors.grey[500]),
          suffixIcon: AnimatedSwitcher(
            duration: switchDuration,
            transitionBuilder: (child, animation) {
              // nice scale + fade
              return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child));
            },
            child: isOverlayOpen.value
                ? // close icon when overlay is open
            IconButton(
              key: const ValueKey('close'),
              icon: const Icon(Icons.close),
              onPressed: () {
                // close overlay and optionally clear input or unfocus
                closeOverlay();
                focusNode.unfocus();
              },
            )
                : // search icon when overlay is closed
            IconButton(
              key: const ValueKey('search'),
              icon: const Icon(Icons.search),
              onPressed: () {
                // open overlay and focus the field so that showAllOnFocus behaviour can fire
                if (!focusNode.hasFocus) {
                  focusNode.requestFocus();
                } else {
                  // if already focused then call openOverlay explicitly
                  openOverlay();
                }
              },
            ),
          ),
        ),
        onChanged: onTextChanged,
        onTap: () {
          // open overlay (and show all if configured)
          if (focusNode.hasFocus) {
            if (showAllOnFocus) {
              // already handled in focus listener
              return;
            }
            if (controller.text.trim().isNotEmpty) {
              onTextChanged(controller.text);
            } else {
              openOverlay();
            }
          }
        },
      ),
    );
  }
}
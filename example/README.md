# Embedded Photo Picker Example

Run `flutter pub get`, then `flutter run -d <android-id>` from this directory
on a supported Android device. See the parent package README for requirements.

The example uses the plugin's declarative selection, typed config, and
`PhotoPickerMedia.loadThumbnail` APIs. No custom native channel or storage
permissions are needed. Selected image/video thumbnails appear in a horizontal
strip with removal controls and loading/error states.

The starting screen offers two examples. Both start with the picker hidden;
the photo button opens it on demand.

- **Compose** opens the existing five-line composer, horizontal previews, and
	expanded picker with a 300ms slide transition. A rounded bottom-sheet header
	above the native surface adjusts the picker height while keeping the message
	controls visible. Dragging it to the bottom closes the picker without clearing
	attachments. Reopening retains the height with a minimum usable size.
	Its Post button is intentionally disabled.
- **Chat** demonstrates continuous photo selection in a collapsed docked picker
	that slides open over 300ms, following
	the Android [continuous-selection reference](https://developer.android.com/static/training/data-storage/shared/photo-picker/assets/continuous2.gif).
	Attachments sit inside the message composer and stay synchronized with the
	picker. Typing hides the picker; the photo button brings it back. Send adds
	a local conversation bubble and clears the sent selection without closing
	the picker. Sent photos use in-memory thumbnail bytes, not original files.

Layout and button styling remain host-owned examples. Neither screen uploads,
persists, or transmits messages or media. Leaving Chat discards its conversation.

The example depends on the package through a relative path, so it can be run
directly from this repository without additional dependency overrides.

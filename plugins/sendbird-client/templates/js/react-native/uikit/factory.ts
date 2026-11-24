// source: https://github.com/sendbird/sendbird-uikit-react-native/blob/main/sample/src/factory/index.ts
// Public sample factory, reduced to the platformServices required by SendbirdUIKitContainer.
import * as ImageResizer from '@bam.tech/react-native-image-resizer';
import { CameraRoll } from '@react-native-camera-roll/camera-roll';
import Clipboard from '@react-native-clipboard/clipboard';
import * as DocumentPicker from '@react-native-documents/picker';
// @react-native-firebase/messaging 26.0.0 removed the default export the sample imports (it pins 19.3.0).
// The module namespace carries the modular API (getMessaging, getToken, AuthorizationStatus, ...)
// from 22.0.0 on, and createNativeNotificationService accepts it (isModularAPI):
// https://github.com/sendbird/sendbird-uikit-react-native/blob/main/packages/uikit-react-native/src/platform/createNotificationService.native.ts
// A project pinned below 22.0.0 has no modular API: import the default export there instead.
import * as RNFBMessaging from '@react-native-firebase/messaging';
import * as FileAccess from 'react-native-file-access';
import * as ImagePicker from 'react-native-image-picker';
import * as AudioRecorderPlayer from 'react-native-nitro-sound';
import * as Permissions from 'react-native-permissions';
import Video from 'react-native-video';

import * as CreateThumbnail from '@sendbird/react-native-create-thumbnail';
import {
  SendbirdUIKitContainerProps,
  createNativeClipboardService,
  createNativeFileService,
  createNativeMediaService,
  createNativeNotificationService,
  createNativePlayerService,
  createNativeRecorderService,
} from '@sendbird/uikit-react-native';

export const platformServices: SendbirdUIKitContainerProps['platformServices'] = {
  clipboard: createNativeClipboardService(Clipboard),
  notification: createNativeNotificationService({
    messagingModule: RNFBMessaging,
    permissionModule: Permissions,
  }),
  file: createNativeFileService({
    imagePickerModule: ImagePicker,
    documentPickerModule: DocumentPicker,
    permissionModule: Permissions,
    fsModule: FileAccess,
    mediaLibraryModule: CameraRoll,
  }),
  media: createNativeMediaService({
    VideoComponent: Video,
    thumbnailModule: CreateThumbnail,
    imageResizerModule: ImageResizer,
  }),
  player: createNativePlayerService({
    audioRecorderModule: AudioRecorderPlayer,
    permissionModule: Permissions,
  }),
  recorder: createNativeRecorderService({
    audioRecorderModule: AudioRecorderPlayer,
    permissionModule: Permissions,
  }),
};

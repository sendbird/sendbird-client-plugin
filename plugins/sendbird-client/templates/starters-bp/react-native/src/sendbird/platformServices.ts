// source: https://github.com/sendbird/sendbird-uikit-react-native/blob/main/sample/src/factory/index.ts
// source: knowledge/curated/js/products/uikit.md ("React Native": platformServices from the createNative*Service factories)
// source: https://sendbird.com/docs/chat/uikit/v3/react-native/essentials/installation
//
// The native services UIKit needs (clipboard, notification, file, media, player, recorder), built
// with the factories the package exports, the same way the public sample does. Each module is a
// native dependency in package.json; follow the installation guide for its native setup.
import * as ImageResizer from '@bam.tech/react-native-image-resizer';
import { CameraRoll } from '@react-native-camera-roll/camera-roll';
import Clipboard from '@react-native-clipboard/clipboard';
import * as DocumentPicker from '@react-native-documents/picker';
import RNFBMessaging from '@react-native-firebase/messaging';
import * as FileAccess from 'react-native-file-access';
import * as ImagePicker from 'react-native-image-picker';
import * as AudioRecorderPlayer from 'react-native-nitro-sound';
import * as Permissions from 'react-native-permissions';
import Video from 'react-native-video';

import * as CreateThumbnail from '@sendbird/react-native-create-thumbnail';
import {
  type SendbirdUIKitContainerProps,
  createNativeClipboardService,
  createNativeFileService,
  createNativeMediaService,
  createNativeNotificationService,
  createNativePlayerService,
  createNativeRecorderService,
} from '@sendbird/uikit-react-native';

export const platformServices: SendbirdUIKitContainerProps['platformServices'] = {
  clipboard: createNativeClipboardService(Clipboard),
  // BP10: UIKit registers this device's push token through this service after connect, and
  // unregisters it on disconnect (useConnection), while auto push token registration is on (default).
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

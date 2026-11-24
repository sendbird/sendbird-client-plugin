// source: https://sendbird.com/docs/chat/uikit/v3/react/theme-and-style-resources/theme-resources
// source: https://sendbird.com/docs/chat/sdk/v4/javascript/local-caching/overview-local-caching
//
// Values handed to SendbirdProvider. They are module constants on purpose: the provider re-applies
// colorSet whenever the object identity changes, so never build these objects inside a component.
import type { SendbirdProviderProps } from '@sendbird/uikit-react/SendbirdProvider';

// BP12: the one place for the UIKit theme.
export const UIKIT_THEME: SendbirdProviderProps['theme'] = 'light';

// Brand colors: map UIKit CSS variable names to values; the brand color goes on 300 (main), 500 is
// darkest and 100 lightest, e.g. { '--sendbird-light-primary-300': '#00487c' }
// Leave undefined to keep the default palette.
export const UIKIT_COLOR_SET: SendbirdProviderProps['colorSet'] = undefined;

// Phone layout below this width. UIKit shows the conversation header's back button only when the
// provider's `breakpoint` matches (the default, false, never does), so the starter passes it and
// switches to one pane at the same width (styles.css).
// source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/lib/MediaQueryContext.tsx#L4-L60
// source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/GroupChannel/components/GroupChannelHeader/GroupChannelHeaderView.tsx#L38-L56
export const UIKIT_BREAKPOINT = '768px';

// BP11: local caching. React UIKit already turns it on; it is spelled out here so it is visible.
// Add supportMultipleTabs: true if users open the app in several tabs.
export const SDK_INIT_PARAMS: SendbirdProviderProps['sdkInitParams'] = { localCacheEnabled: true };

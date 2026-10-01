<!-- last-verified-against: conceptual (no version-specific API) -->
<!-- verified-at: 2026-09-22 -->
<!-- status: populated -->
# Sendbird — Core Concepts

## Overview
Sendbird is organized around a few stable ideas that hold across every product and platform. This file is conceptual: it defines terms, not API calls. For any code, see the platform guides and cite a verified source.

## The building blocks
- Application: your Sendbird app, identified by an Application ID (app_id). All data is scoped to one application.
- User: an end user of your app. Users connect to Sendbird with a user identifier, optionally authenticated with a token.
- Channel / Conversation: where messaging happens. Chat uses channels (group and open); AI Agent uses a conversation surface with its own vocabulary.
- Message: the unit exchanged in a channel or conversation.
- Region: the data region your application is hosted in. Most apps use the default; some use a dedicated region.

## Products at a glance (conceptual)
- Chat: real-time messaging (channels, messages, members). Includes the connection/session (auth) layer.
- UIKit: prebuilt UI on top of Chat.
- AI Agent: an AI-driven conversation experience with its own UI vocabulary (conversation, conversation list, launcher).
- Desk: support-ticket workflows.
- Calls: voice/video.
- Live: live streaming.

## Where IDs and keys come from
The Application ID and credentials come from the Sendbird dashboard. This guide does not reproduce dashboard click-paths (they change) — follow the official docs for the exact navigation.

## Related
- Official docs: https://sendbird.com/docs

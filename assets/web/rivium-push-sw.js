/**
 * RiviumPush Service Worker
 * Handles background push notifications with rich features
 *
 * Copy this file to your public directory as 'rivium-push-sw.js'
 */

// Cache name for offline support
const CACHE_NAME = 'rivium-push-v0.1.10';

/**
 * Where the worker gets its API key and device id.
 *
 * A service worker is terminated between pushes, so nothing can be kept in
 * memory. Two durable places hold the config, and both are read:
 *
 *  1. The registration URL's query string. The browser persists the script
 *     URL, so this is available immediately on every wake-up.
 *  2. IndexedDB (`rivium-push` / `config`), written by the SDK on every load.
 *     This is the fallback for a worker registered WITHOUT the query string -
 *     an app (or another library, or a hot reload in development) that calls
 *     `navigator.serviceWorker.register('/rivium-push-sw.js')` itself. Such a
 *     worker still shows notifications, but used to silently stop confirming
 *     delivery and stop re-registering a changed subscription.
 *
 * The URL wins field by field, so an explicit registration still decides.
 */
const RIVIUM_DB_NAME = 'rivium-push';
const RIVIUM_DB_STORE = 'config';
const RIVIUM_DB_KEY = 'config';
const RIVIUM_DEFAULT_SERVER_URL = 'https://push-api.rivium.co';

function riviumConfigFromUrl() {
  try {
    const params = new URL(self.location.href).searchParams;
    return {
      apiKey: params.get('riviumApiKey') || null,
      serverUrl: params.get('riviumServerUrl') || null,
      deviceId: params.get('riviumDeviceId') || null,
      // Added in 0.1.5. SDKs older than 0.1.5 don't pass it.
      sdkVersion: params.get('riviumSdkVersion') || null,
    };
  } catch (e) {
    return { apiKey: null, serverUrl: null, deviceId: null, sdkVersion: null };
  }
}

/** The SDK's last known config, or null. Never rejects: storage may be unavailable. */
function riviumConfigFromStorage() {
  return new Promise((resolve) => {
    let request;
    try {
      request = indexedDB.open(RIVIUM_DB_NAME, 1);
    } catch (e) {
      return resolve(null);
    }
    // The SDK creates the store; a worker that gets here first must not leave
    // an empty database behind with a half-made schema.
    request.onupgradeneeded = () => {
      try {
        request.result.createObjectStore(RIVIUM_DB_STORE);
      } catch (e) {
        /* already there */
      }
    };
    request.onerror = () => resolve(null);
    request.onsuccess = () => {
      const db = request.result;
      try {
        const get = db.transaction(RIVIUM_DB_STORE, 'readonly').objectStore(RIVIUM_DB_STORE).get(RIVIUM_DB_KEY);
        get.onsuccess = () => {
          resolve(get.result || null);
          db.close();
        };
        get.onerror = () => {
          resolve(null);
          db.close();
        };
      } catch (e) {
        resolve(null);
        db.close();
      }
    };
  });
}

let riviumConfigPromise = null;

/** Resolved config for this wake-up. Storage is read only when the URL is short of something. */
function riviumConfig() {
  const fromUrl = riviumConfigFromUrl();
  if (fromUrl.apiKey && fromUrl.deviceId) {
    return Promise.resolve({ ...fromUrl, serverUrl: fromUrl.serverUrl || RIVIUM_DEFAULT_SERVER_URL });
  }
  riviumConfigPromise = riviumConfigPromise || riviumConfigFromStorage();
  return riviumConfigPromise.then((stored) => ({
    apiKey: fromUrl.apiKey || (stored && stored.apiKey) || null,
    serverUrl: fromUrl.serverUrl || (stored && stored.serverUrl) || RIVIUM_DEFAULT_SERVER_URL,
    deviceId: fromUrl.deviceId || (stored && stored.deviceId) || null,
    sdkVersion: fromUrl.sdkVersion || (stored && stored.sdkVersion) || null,
  }));
}

/**
 * Confirm delivery to Rivium Push.
 *
 * Web Push, APNs and FCM all report only that the push service *accepted* a
 * notification — none of them confirm it reached the device. This ack is the
 * only signal that it actually arrived, so the dashboard can distinguish
 * "accepted" from "delivered".
 *
 * Best-effort: a failure here must never stop the notification being shown.
 */
function riviumReportDelivered(messageId) {
  if (!messageId) {
    console.warn('[RiviumPush SW] Delivery ack skipped - the push carried no message id');
    return Promise.resolve();
  }

  return riviumConfig().then((config) => {
    if (!config.apiKey || !config.deviceId) {
      console.warn(
        '[RiviumPush SW] Delivery ack skipped - no SDK config in the worker URL or in storage: ' +
          (!config.apiKey ? 'apiKey' : '') +
          (!config.apiKey && !config.deviceId ? ' and ' : '') +
          (!config.deviceId ? 'deviceId' : '') +
          ' missing. Register the worker through the SDK (init/register) so it can confirm delivery.',
      );
      return;
    }

    // No `keepalive`: event.waitUntil already holds the worker open, and
    // keepalive is unreliable for fetches issued from a service worker.
    return fetch(`${config.serverUrl}/receipts/delivered`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': config.apiKey,
      },
      body: JSON.stringify({ messageId, deviceId: config.deviceId }),
    })
      .then((res) => {
        // A non-2xx is a failure - resolving on it would hide the problem the
        // same way the server used to hide an ack for a receipt that did not
        // exist yet.
        if (!res.ok) {
          console.warn('[RiviumPush SW] Delivery ack rejected', res.status);
          return;
        }
        console.log('[RiviumPush SW] Delivery confirmed', messageId);
      })
      .catch((err) => {
        console.warn('[RiviumPush SW] Delivery ack failed:', err && err.message);
      });
  });
}

/** "<kind>:<messageId>" already reported while this worker is alive. */
const riviumReportedInteractions = new Set();
const RIVIUM_INTERACTION_RETRY_DELAYS_MS = [1000, 3000];

/**
 * Report what the user did with a notification: `opened` (body clicked),
 * `clicked` (an action button, with its id) or `dismissed` (closed without a
 * click). Same headers as the delivery ack. Sent once per message and kind,
 * retried briefly on network errors, 429 and 5xx. Never rejects, and is run
 * next to opening the window, never before it.
 */
function riviumReportInteraction(kind, messageId, actionId) {
  if (!messageId) return Promise.resolve();
  const key = kind + ':' + messageId;
  if (riviumReportedInteractions.has(key)) return Promise.resolve();
  riviumReportedInteractions.add(key);
  if (riviumReportedInteractions.size > 500) {
    riviumReportedInteractions.delete(riviumReportedInteractions.values().next().value);
  }

  return riviumConfig()
    .then((config) => {
      if (!config.apiKey || !config.deviceId) {
        riviumReportedInteractions.delete(key);
        console.warn('[RiviumPush SW] ' + kind + ' receipt skipped - no SDK config in the worker URL or in storage');
        return;
      }
      const body = { messageId, deviceId: config.deviceId };
      if (kind === 'clicked' && actionId) body.actionId = actionId;

      const attempt = (n) =>
        fetch(`${config.serverUrl}/receipts/${kind}`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': config.apiKey,
          },
          body: JSON.stringify(body),
        })
          .then((res) => {
            if (res.ok) return true;
            const retryable = res.status === 429 || res.status >= 500;
            console.warn('[RiviumPush SW] ' + kind + ' receipt rejected', res.status);
            return retryable ? null : false;
          })
          .catch((err) => {
            console.warn('[RiviumPush SW] ' + kind + ' receipt failed:', err && err.message);
            return null;
          })
          .then((result) => {
            if (result !== null || n >= RIVIUM_INTERACTION_RETRY_DELAYS_MS.length) {
              if (result !== true) riviumReportedInteractions.delete(key);
              return;
            }
            return new Promise((resolve) => setTimeout(resolve, RIVIUM_INTERACTION_RETRY_DELAYS_MS[n])).then(() =>
              attempt(n + 1),
            );
          });
      return attempt(0);
    })
    .catch(() => {
      riviumReportedInteractions.delete(key);
    });
}

// Install event
self.addEventListener('install', (event) => {
  console.log('[RiviumPush SW] Installing...');
  self.skipWaiting();
});

// Activate event
self.addEventListener('activate', (event) => {
  console.log('[RiviumPush SW] Activating...');
  event.waitUntil(self.clients.claim());
});

// Push event - received push notification
self.addEventListener('push', (event) => {
  console.log('[RiviumPush SW] Push received');

  let data = {
    title: 'New notification',
    body: '',
    icon: '/icon.png',
    badge: '/badge.png',
    data: {},
  };

  if (event.data) {
    try {
      const payload = event.data.json();
      data = {
        ...data,
        ...payload,
      };
    } catch (e) {
      data.body = event.data.text();
    }
  }

  // Get localized content if available
  const localizedTitle = getLocalizedContent(data, 'title');
  const localizedBody = getLocalizedContent(data, 'body');

  const options = {
    body: localizedBody || data.body,
    // Icons must resolve to a real file. Android Chrome silently drops a
    // notification when the icon 404s (desktop is more forgiving), so keep
    // /icon.png and /badge.png present in your public directory, or always
    // send iconUrl from the backend.
    icon: data.iconUrl || data.icon || '/icon.png',
    // `badge` is the small monochrome icon Android shows in the status bar.
    badge: data.badgeIcon || data.iconUrl || data.icon || '/badge.png',
    image: data.imageUrl || data.image,
    // Per-message uniqueness by default. A fixed tag collapses every push
    // into one slot in the Android shade — new notifications silently replace
    // older ones and the user never sees the second, third, … arrive. The
    // backend still opts into grouping by sending an explicit tag or
    // collapseKey (e.g. to fold "N liked your post" into one).
    tag:
      data.tag ||
      data.collapseKey ||
      data.threadId ||
      data.messageId ||
      `rivium-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    // renotify forces Android Chrome to actually surface the notification
    // while Chrome is backgrounded but not closed. Without it Chrome treats
    // the origin as "about to be focused" and swallows showNotification — the
    // worker logs success and the shade stays empty. Harmless elsewhere.
    renotify: true,
    // A second signal to Android that this is a fresh user-visible event.
    // Ignored on desktop.
    // `vibrate: false` comes from a notification channel without vibration (Rivium Console).
    vibrate: data.vibrate === false ? [] : [200, 100, 200],
    data: {
      ...data.data,
      deepLink: data.deepLink,
      messageId: data.messageId,
      campaignId: data.campaignId,
      riviumPushPayload: data,
    },
    requireInteraction: true,
    silent: data.sound === 'none',
    actions: [],
  };

  // Add action buttons (max 2 for web)
  if (data.actions && Array.isArray(data.actions)) {
    options.actions = data.actions.slice(0, 2).map((action) => ({
      action: action.id,
      title: action.title,
      icon: action.icon,
    }));
  }

  // Show notification with potentially localized title
  let title = localizedTitle || data.title;
  const conversation = riviumConversationOf(data.data, title);

  event.waitUntil((async () => {
    // A chat message (data.conversationId): one notification per conversation, the sender's photo, earlier lines kept.
    if (conversation) {
      const tag = 'rivium-conversation:' + conversation.id;
      let previous = [];
      try {
        const open = await self.registration.getNotifications({ tag });
        previous = (open[0] && open[0].data && open[0].data.riviumConversationLines) || [];
      } catch (err) {
        previous = [];
      }
      const view = riviumConversationView(conversation, options.body || '', previous);
      title = view.title;
      options.body = view.body;
      options.tag = tag;
      options.data.riviumConversationLines = view.lines;
      if (conversation.avatarUrl) options.icon = conversation.avatarUrl;
      delete options.image;
    }

    // Mirror the payload to any visible page. On mobile the app is usually
    // backgrounded or the screen is locked, so the page-side connection is
    // asleep and only the worker sees the push. Pages should dedupe by
    // messageId, since a foreground client may receive it both ways.
    try {
      const clientsList = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });
      for (const client of clientsList) {
        client.postMessage({
          type: 'rivium-push-message',
          message: {
            title,
            body: localizedBody || data.body,
            data: data.data || {},
            deepLink: data.deepLink,
            messageId: data.messageId,
            campaignId: data.campaignId,
          },
        });
      }
    } catch (err) {
      console.warn('[RiviumPush SW] client postMessage failed:', err);
    }

    // Always show the OS notification: Chrome's user-visible contract revokes
    // subscriptions that push silently. Wrapped so an Android quirk that would
    // otherwise fail silently surfaces here; the retry drops the optional
    // fields (icon/badge/image/actions) that are the usual cause.
    try {
      await self.registration.showNotification(title, options);
    } catch (err) {
      console.warn('[RiviumPush SW] showNotification failed, retrying minimal', err);
      try {
        await self.registration.showNotification(title, {
          body: options.body,
          tag: options.tag,
          data: options.data,
        });
      } catch (err2) {
        console.error('[RiviumPush SW] showNotification (minimal) failed too', err2);
      }
    }

    // Confirm arrival so the dashboard can show `delivered`, not only `sent`.
    await riviumReportDelivered(data.messageId);
  })());
});

/**
 * The browser can rotate a push subscription at any time — after a long idle
 * period, a browser update, or when it decides the old endpoint is stale.
 * Without this handler the old endpoint stays registered server-side, keeps
 * returning 410 Gone, and the user silently stops receiving notifications.
 *
 * Re-subscribe with the same VAPID key and register the new endpoint.
 */
self.addEventListener('pushsubscriptionchange', (event) => {
  console.log('[RiviumPush SW] Push subscription changed, re-subscribing');

  const applicationServerKey =
    (event.oldSubscription &&
      event.oldSubscription.options &&
      event.oldSubscription.options.applicationServerKey) ||
    null;

  if (!applicationServerKey) {
    console.warn('[RiviumPush SW] Cannot re-subscribe: the old subscription carried no VAPID key');
    return;
  }

  event.waitUntil(
    riviumConfig()
      .then((config) => {
        if (!config.apiKey || !config.deviceId) {
          console.warn(
            '[RiviumPush SW] Cannot re-subscribe: no SDK config in the worker URL or in storage',
          );
          return;
        }
        return self.registration.pushManager
          .subscribe({ userVisibleOnly: true, applicationServerKey })
          .then((subscription) =>
            fetch(`${config.serverUrl}/devices/register`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'x-api-key': config.apiKey,
              },
              body: JSON.stringify({
                deviceId: config.deviceId,
                platform: 'web',
                appIdentifier: self.location.origin,
                webPushSubscription: subscription.toJSON(),
                // 0.1.5: SDK identity (body, not header, to avoid a CORS preflight).
                sdkName: 'web',
                ...(config.sdkVersion ? { sdkVersion: config.sdkVersion } : {}),
              }),
            }),
          )
          .then(() => {
            console.log('[RiviumPush SW] Re-subscribed and re-registered');
          });
      })
      .catch((err) => {
        console.error('[RiviumPush SW] Re-subscribe failed:', err && err.message);
      }),
  );
});

// Chat-style notifications (same rules as src/conversation.ts).
function riviumConversationOf(data, fallbackSender) {
  if (!data) return null;
  const text = (v) => (v === undefined || v === null ? undefined : String(v).trim() || undefined);
  const id = text(data.conversationId);
  if (!id) return null;
  const avatar = text(data.senderAvatarUrl);
  return {
    id: id.slice(0, 200),
    senderName: text(data.senderName) || fallbackSender || '?',
    avatarUrl: avatar && /^https?:\/\//i.test(avatar) ? avatar : undefined,
    title: text(data.conversationTitle),
    isGroup: data.conversationIsGroup === true || String(data.conversationIsGroup).toLowerCase() === 'true',
  };
}

function riviumConversationView(c, body, previousLines) {
  const line = c.isGroup ? c.senderName + ': ' + body : body;
  const before = Array.isArray(previousLines) ? previousLines.filter((l) => typeof l === 'string') : [];
  const lines = before.concat([line]).slice(-5);
  return { title: c.isGroup && c.title ? c.title : c.senderName, body: lines.join('\n'), lines };
}

// Helper function to get localized content
function getLocalizedContent(data, field) {
  if (!data.localizations || !Array.isArray(data.localizations)) {
    return null;
  }

  // Get device locale (best effort in service worker context)
  let deviceLocale = 'en';
  try {
    deviceLocale = navigator.language.split('-')[0].toLowerCase();
  } catch (e) {
    // Fallback to 'en'
  }

  const localized = data.localizations.find((loc) =>
    loc.locale.toLowerCase().startsWith(deviceLocale)
  );

  return localized ? localized[field] : null;
}

// Notification click event
self.addEventListener('notificationclick', (event) => {
  console.log('[RiviumPush SW] Notification clicked');

  const notification = event.notification;
  const action = event.action;
  const data = notification.data || {};
  const riviumPushPayload = data.riviumPushPayload || {};

  notification.close();

  // Determine if this is an action button click
  const isActionClick = action && action !== '';

  // Find action details if action button was clicked
  let actionDetails = null;
  let targetUrl = null;

  if (isActionClick && riviumPushPayload.actions) {
    // Action button was clicked - find the action's URL
    actionDetails = riviumPushPayload.actions.find((a) => a.id === action);
    if (actionDetails && actionDetails.action) {
      targetUrl = actionDetails.action;
    }
  }

  // If no URL yet, try deepLink
  if (!targetUrl) {
    targetUrl = data.deepLink || riviumPushPayload.deepLink || data.url || data.click_action;
  }

  // If still no URL but has actions, use first action's URL as fallback
  if (!targetUrl && riviumPushPayload.actions && riviumPushPayload.actions.length > 0) {
    const firstAction = riviumPushPayload.actions[0];
    if (firstAction && firstAction.action) {
      targetUrl = firstAction.action;
      console.log('[RiviumPush SW] Using first action URL as fallback:', targetUrl);
    }
  }

  // Default to root if nothing else
  if (!targetUrl) {
    targetUrl = '/';
  }

  console.log('[RiviumPush SW] Target URL:', targetUrl);

  // Opened (body) or clicked (action button) receipt, sent next to opening
  // the window so the click never waits for the network.
  const receipt = riviumReportInteraction(
    isActionClick ? 'clicked' : 'opened',
    data.messageId || riviumPushPayload.messageId,
    isActionClick ? action : undefined,
  );

  const openOrFocus =
    self.clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // If we have a URL to open, just open it directly
        if (targetUrl && targetUrl !== '/') {
          console.log('[RiviumPush SW] Opening URL:', targetUrl);
          return self.clients.openWindow(targetUrl);
        }

        // No external URL - check if there's already an open window to focus
        for (const client of clientList) {
          if (client.url.includes(self.location.origin) && 'focus' in client) {
            // Send message to client
            if (isActionClick) {
              client.postMessage({
                type: 'action-clicked',
                actionId: action,
                actionDetails: actionDetails,
                message: {
                  title: notification.title,
                  body: notification.body,
                  data: data,
                  deepLink: data.deepLink,
                  messageId: data.messageId,
                  campaignId: data.campaignId,
                },
              });
            } else {
              client.postMessage({
                type: 'notification-click',
                action: action,
                message: {
                  title: notification.title,
                  body: notification.body,
                  data: data,
                  deepLink: data.deepLink,
                  messageId: data.messageId,
                  campaignId: data.campaignId,
                },
              });
            }

            return client.focus();
          }
        }

        // No window open: open the app with the message, which getInitialMessage() reads from the URL.
        if (self.clients.openWindow) {
          const opened = {
            title: notification.title,
            body: notification.body,
            data: data,
            deepLink: data.deepLink,
            messageId: data.messageId,
            campaignId: data.campaignId,
          };
          // The app is the folder the worker is served from (it sits next to index.html).
          let url = '/';
          try {
            const target = new URL('./', self.location.href);
            target.searchParams.set('rivium_push_notification', JSON.stringify(opened));
            url = target.href;
          } catch (e) {
            url = '/';
          }
          return self.clients.openWindow(url);
        }
      });

  event.waitUntil(Promise.all([openOrFocus, receipt]));
});

// Notification close event
self.addEventListener('notificationclose', (event) => {
  console.log('[RiviumPush SW] Notification closed');

  const notification = event.notification;
  const data = notification.data || {};

  // Send dismissal event to clients
  const notifyClients = self.clients.matchAll({ type: 'window', includeUncontrolled: true })
    .then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin)) {
          client.postMessage({
            type: 'notification-dismissed',
            message: {
              title: notification.title,
              body: notification.body,
              messageId: data.messageId,
              campaignId: data.campaignId,
            },
          });
        }
      }
    })
    .catch(() => undefined);

  // The browser fires this only when the user closes the notification
  // without clicking it (a click closes it through notification.close()).
  const riviumPushPayload = data.riviumPushPayload || {};
  event.waitUntil(
    Promise.all([notifyClients, riviumReportInteraction('dismissed', data.messageId || riviumPushPayload.messageId)]),
  );
});

// Message from main app
self.addEventListener('message', (event) => {
  console.log('[RiviumPush SW] Message received:', event.data);

  if (event.data.type === 'skip-waiting') {
    self.skipWaiting();
  }

  if (event.data.type === 'clear-badge') {
    // Handle badge clearing if needed
  }
});

// Background sync (for offline message queue)
self.addEventListener('sync', (event) => {
  console.log('[RiviumPush SW] Sync event:', event.tag);

  if (event.tag === 'rivium-push-sync') {
    event.waitUntil(syncMessages());
  }
});

// Sync queued messages
async function syncMessages() {
  console.log('[RiviumPush SW] Syncing messages...');
  // Implement if you need to sync messages when coming back online
}

// Periodic background sync (if supported)
self.addEventListener('periodicsync', (event) => {
  if (event.tag === 'rivium-push-periodic-sync') {
    event.waitUntil(doPeriodicSync());
  }
});

async function doPeriodicSync() {
  console.log('[RiviumPush SW] Periodic sync...');
  // Implement periodic sync if needed
}

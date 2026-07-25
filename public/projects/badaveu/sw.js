const CACHE_NAME = 'badaveu-v4.7';
const STATIC_ASSETS = [
    '/',
    '/index.html',
    '/about.html',
    '/stats.html',
    '/incidents.html',
    '/incident.html',
    '/landing.html',
    '/offline.html',
    '/manifest.json',
    '/assets/css/style.css?v=3.7',
    '/assets/js/core.js?v=3.7',
    '/assets/js/app.js?v=3.7',
    'https://cdn.jsdelivr.net/npm/remixicon@3.5.0/fonts/remixicon.css',
    'https://unpkg.com/leaflet/dist/leaflet.css',
    'https://unpkg.com/leaflet/dist/leaflet.js',
    'https://unpkg.com/leaflet.markercluster/dist/MarkerCluster.Default.css',
    'https://unpkg.com/leaflet.markercluster/dist/leaflet.markercluster.js',
];

// ── Install: pre-cache all static assets ─────────────────────────────────────
self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => cache.addAll(STATIC_ASSETS))
            .then(() => self.skipWaiting())
    );
});

// ── Activate: purge old caches ────────────────────────────────────────────────
self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys()
            .then(keys => Promise.all(
                keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
            ))
            .then(() => self.clients.claim())
    );
});

// ── Fetch ─────────────────────────────────────────────────────────────────────
self.addEventListener('fetch', event => {
    if (!event.request.url.startsWith('http')) return;

    const url = new URL(event.request.url);

    // Network-only for API calls — never serve stale data from the API
    if (url.pathname.includes('/api/')) {
        event.respondWith(
            fetch(event.request).catch(() => new Response(
                JSON.stringify({ status: 'error', message: 'Sin connexió' }),
                { headers: { 'Content-Type': 'application/json' } }
            ))
        );
        return;
    }

    // Stale-While-Revalidate for all static assets:
    // → Serve immediately from cache (fast), then fetch fresh copy in the
    //   background and update the cache silently for the next visit.
    event.respondWith(staleWhileRevalidate(event.request));
});

async function staleWhileRevalidate(request) {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request);

    // Kick off a background network fetch regardless of cache hit
    const networkFetch = fetch(request).then(response => {
        if (response && response.status === 200 && request.method === 'GET') {
            cache.put(request, response.clone());
        }
        return response;
    }).catch(() => null);

    // Return cached version immediately if available; otherwise wait for network
    if (cached) return cached;

    const networkResponse = await networkFetch;
    if (networkResponse) return networkResponse;

    // Ultimate fallback: offline page for navigation requests
    if (request.mode === 'navigate') {
        return cache.match('/offline.html');
    }
}

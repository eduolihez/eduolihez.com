// ===========================================================================
//  Service worker de BadaVeu
//
//  CORREGIDO tras mover la aplicacion a /projects/badaveu/:
//
//  1. Las rutas eran absolutas ('/index.html', '/about.html'...) y desde el
//     traslado apuntaban a la raiz del dominio, donde ya no existe casi
//     ninguna: 7 de 8 daban 404. Como cache.addAll() es atomico, una sola
//     que falle rechaza la promesa entera, el evento install nunca termina
//     y el service worker NO llega a instalarse. El modo sin conexion
//     llevaba roto desde entonces. Ahora son relativas ('./'), que se
//     resuelven contra la carpeta del propio service worker.
//
//  2. Las dependencias externas se precacheaban sin fijar version
//     ('leaflet/dist/leaflet.js'), mientras el HTML ya pide 1.9.4. Se
//     guardaba una copia que nadie llegaba a usar. Ahora coinciden.
//
//  3. Se precacheaban assets con '?v=3.7', una version que ninguna pagina
//     pide (usan 2.1, 3.0 y 4.0), asi que la entrada guardada nunca casaba
//     con la solicitada. Ahora se guardan sin la cadena de consulta y se
//     comparan con ignoreSearch, de modo que cualquier '?v=' la encuentra.
// ===========================================================================

const CACHE_NAME = 'badaveu-v5.0';

// Archivos propios: si alguno falla, el precacheo debe fallar y enterarnos.
const LOCAL_ASSETS = [
    './',
    './index.html',
    './about.html',
    './guia.html',
    './stats.html',
    './incidents.html',
    './incident.html',
    './landing.html',
    './offline.html',
    './manifest.json',
    './assets/css/style.css',
    './assets/js/core.js',
    './assets/js/app.js',
];

// Dependencias externas: mismas versiones fijas que cargan las paginas.
// Van aparte porque un CDN caido no debe impedir que la app se instale.
const CDN_ASSETS = [
    'https://cdn.jsdelivr.net/npm/remixicon@3.5.0/fonts/remixicon.css',
    'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
    'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
    'https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css',
    'https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js',
];

// ── Install: precachea lo propio y, aparte, lo externo ──────────────────────
self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(async cache => {
                // Lo propio: atomico. Si falla, queremos que se note.
                await cache.addAll(LOCAL_ASSETS);
                // Lo externo: uno a uno y sin cortar la instalacion si algo falla.
                await Promise.all(
                    CDN_ASSETS.map(url => cache.add(url).catch(() => null))
                );
            })
            .then(() => self.skipWaiting())
    );
});

// ── Activate: borra las caches antiguas ─────────────────────────────────────
self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys()
            .then(keys => Promise.all(
                keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
            ))
            .then(() => self.clients.claim())
    );
});

// ── Fetch ───────────────────────────────────────────────────────────────────
self.addEventListener('fetch', event => {
    if (!event.request.url.startsWith('http')) return;

    const url = new URL(event.request.url);

    // El API siempre por red: nunca servir datos caducados de incidencias.
    if (url.pathname.includes('/api/')) {
        event.respondWith(
            fetch(event.request).catch(() => new Response(
                JSON.stringify({ status: 'error', message: 'Sin connexió' }),
                { headers: { 'Content-Type': 'application/json' } }
            ))
        );
        return;
    }

    event.respondWith(staleWhileRevalidate(event.request));
});

async function staleWhileRevalidate(request) {
    const cache = await caches.open(CACHE_NAME);

    // ignoreSearch: 'style.css?v=3.0' encuentra la copia guardada como
    // 'style.css'. Sin esto, cambiar la cadena de version invalidaba de
    // golpe todo el precacheo.
    const cached = await cache.match(request, { ignoreSearch: true });

    const networkFetch = fetch(request).then(response => {
        if (response && response.status === 200 && request.method === 'GET') {
            cache.put(request, response.clone());
        }
        return response;
    }).catch(() => null);

    if (cached) return cached;

    const networkResponse = await networkFetch;
    if (networkResponse) return networkResponse;

    // Ultimo recurso al navegar sin conexion. Relativa, como el resto.
    if (request.mode === 'navigate') {
        return cache.match('./offline.html');
    }
}

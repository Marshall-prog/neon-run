// NEON RUN - service worker
// Posle pervogo vizita vse fajly igry lezhat v Cache API: povtornyj zapusk
// mgnovennyj, oflajn tozhe rabotaet. Strategiya:
//   * navigaciya (index.html) - network-first, chtoby obnovleniya priletali srazu;
//   * statika (wasm/pck/js/png) - cache-first, promah zapolnyaetsya iz seti.
// Keš ne prekeshiruetsya: fajly kladet sam Godot pervym fetch-em, poetomu
// dvojnoj zagruzki 50 MB pri ustanovke net.

const CACHE = 'neon-run-v2';

self.addEventListener('install', () => {
	self.skipWaiting();
});

self.addEventListener('activate', (event) => {
	event.waitUntil((async () => {
		const keys = await caches.keys();
		await Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)));
		await self.clients.claim();
	})());
});

self.addEventListener('fetch', (event) => {
	const req = event.request;
	if (req.method !== 'GET') return;

	const url = new URL(req.url);
	if (url.origin !== self.location.origin) return;

	// Stranica: snachala set, pri oflajne - keš.
	if (req.mode === 'navigate') {
		event.respondWith((async () => {
			try {
				const fresh = await fetch(req);
				const cache = await caches.open(CACHE);
				cache.put(req, fresh.clone());
				return fresh;
			} catch (err) {
				const cache = await caches.open(CACHE);
				return (await cache.match(req)) ||
					(await cache.match('./index.html')) ||
					Response.error();
			}
		})());
		return;
	}

	// Statika igry: keš vpered, promah - set i v keš.
	event.respondWith((async () => {
		const cache = await caches.open(CACHE);
		const hit = await cache.match(req, { ignoreSearch: true });
		if (hit) return hit;
		const res = await fetch(req);
		if (res && (res.ok || res.type === 'opaque')) {
			cache.put(req, res.clone()).catch(() => {});
		}
		return res;
	})());
});

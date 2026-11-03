const CACHE = 'raulzito-kite-shell-v6';
const SHELL = ['/admin.html','/admin.css','/admin.js','/admin-config.js','/admin-alunos.html','/admin-alunos.css','/admin-alunos.js','/aluno.html','/aluno.css','/aluno.js','/aluno-config.js','/manifest.webmanifest','/manifest-aluno.webmanifest','/assets/pwa-192.png','/assets/pwa-512.png'];
self.addEventListener('install', event => { event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(SHELL))); self.skipWaiting(); });
self.addEventListener('activate', event => { event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key))))); self.clients.claim(); });
self.addEventListener('fetch', event => {
  const req = event.request, url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== self.location.origin || url.pathname.includes('/rest/') || url.pathname.includes('/auth/')) return;
  if (!SHELL.includes(url.pathname) && url.pathname !== '/') return;
  event.respondWith(fetch(req).then(response => { if (response.ok) { const copy=response.clone(); caches.open(CACHE).then(cache=>cache.put(req,copy)); } return response; }).catch(() => caches.match(req)));
});

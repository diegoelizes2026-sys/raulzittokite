const CACHE = 'raulzito-kite-shell-v13';
const SHELL = ['/','/index.html','/styles.css','/script.js','/config.js','/admin.html','/admin.css','/admin.js','/admin-config.js','/admin-alunos.html','/admin-alunos.css','/admin-alunos.js','/aluno.html','/aluno.css','/aluno.js','/aluno-config.js','/manifest.webmanifest','/manifest-aluno.webmanifest','/manifest-public.webmanifest','/assets/pwa-192.png','/assets/pwa-512.png','/assets/raulzito-kite-icon.png','/assets/raulzito-kite-logo.png'];
self.addEventListener('install', event => {
 event.waitUntil(caches.open(CACHE).then(cache => Promise.all(SHELL.map(path => fetch(path,{cache:'reload'}).then(response => response.ok ? cache.put(path,response) : null).catch(() => null)))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => { event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', event => {
 const req=event.request,url=new URL(req.url);
 if(req.method!=='GET'||url.origin!==self.location.origin||url.pathname.includes('/rest/')||url.pathname.includes('/auth/')||url.pathname.includes('/realtime/'))return;
 if(req.mode==='navigate'){
  event.respondWith(fetch(req).then(response=>{if(response.ok){const copy=response.clone();caches.open(CACHE).then(cache=>cache.put(req,copy));}return response;}).catch(async()=>await caches.match(req)||await caches.match('/index.html')||Response.error()));
  return;
 }
 if(SHELL.includes(url.pathname))event.respondWith(caches.match(req).then(cached=>cached||fetch(req).then(response=>{if(response.ok){const copy=response.clone();caches.open(CACHE).then(cache=>cache.put(req,copy));}return response;})));
});

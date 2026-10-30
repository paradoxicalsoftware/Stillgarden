const CACHE='stillgarden-1.1.0';
const AUDIO=['day-spring','day-summer','day-autumn','day-winter','night-spring','night-summer','night-autumn','night-winter','rain','wind','owl-call','thunder-0','thunder-1','thunder-2'];
const CORE=['./','./index.html','./style.css','./app.js','./model.js','./render.js','./audio.js','./manifest.webmanifest','./assets/garden.jpg','./assets/icon.png',...AUDIO.map(name=>`./assets/${name}.mp3`)];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(CORE))));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('stillgarden-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
 if(event.request.method!=='GET'||new URL(event.request.url).origin!==self.location.origin)return;
 event.respondWith(caches.open(CACHE).then(async cache=>{
  const cached=await cache.match(event.request.url),range=event.request.headers.get('range');
  if(cached){
   if(range){const data=await cached.arrayBuffer(),match=/^bytes=(\d+)-(\d*)$/.exec(range);if(match){const start=Number(match[1]),end=Math.min(data.byteLength-1,match[2]?Number(match[2]):data.byteLength-1);if(start>end)return new Response(null,{status:416,headers:{'Content-Range':`bytes */${data.byteLength}`}});return new Response(data.slice(start,end+1),{status:206,headers:{'Content-Type':cached.headers.get('Content-Type')||'audio/mpeg','Content-Range':`bytes ${start}-${end}/${data.byteLength}`,'Content-Length':String(end-start+1),'Accept-Ranges':'bytes'}});}}
   return cached;
  }
  const response=await fetch(event.request);if(response.ok&&response.status===200)await cache.put(event.request,response.clone());return response;
 }));
});

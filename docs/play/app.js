import * as M from './model.js';
import {Renderer} from './render.js';
import {Soundscape} from './audio.js';
const $=id=>document.getElementById(id),bridge=window.stillgarden,KEY='stillgarden.portable.v1';
const renderer=new Renderer($('scene')),audio=new Soundscape();
let state,backup=null,selected='',planting=null,lastTick=Date.now(),lastSave=0,lastEdge=Date.now(),hidden=false,hideAt=0,revealAt=0,lightTransition=null,weatherTransition=null,strikes=[],nextStrike=0,ready=false;
const message=text=>{$('message').textContent=text;};
try{
 const data=bridge?await bridge.load():JSON.parse(localStorage.getItem(KEY)||'null');
 state=data?.state?M.normalize(data.state):M.freshState();backup=data?.backup?M.normalize(data.backup):null;
 M.advance(state,Math.max(0,(Date.now()-state.savedAt)/1000));
}catch(error){state=M.freshState();message(`Could not load saved garden: ${error.message}. Export before closing if storage is unavailable.`);}
const platform=bridge?await bridge.platform():{desktop:false};
let saveQueue=Promise.resolve();
function snapshot(){state.savedAt=Date.now();return JSON.stringify({state,backup});}
function save(){const value=snapshot();if(bridge){saveQueue=saveQueue.catch(()=>{}).then(()=>bridge.save(value)).catch(e=>message(`Could not save: ${e.message}`));return saveQueue;}try{localStorage.setItem(KEY,value);return Promise.resolve();}catch(e){message('Browser storage is unavailable or full. Export your garden to keep it.');return Promise.reject(e);}}
function persist(){save().catch(()=>{});}
function displayHour(now){const target=M.hour(state,now,Math.max(0,(now-lastTick)/1000));if(!lightTransition)return target;const t=(now-lightTransition.at)/lightTransition.duration;if(t>=1){lightTransition=null;return target;}return M.wrap(lightTransition.from+(M.wrap(target-lightTransition.from+12)-12)*M.smooth(t));}
function displayWeather(now){const target=M.weather(state,now);if(!weatherTransition)return target;const t=(now-weatherTransition.at)/4000;if(t>=1){weatherTransition=null;return target;}return M.blend(weatherTransition.from,target,t);}
function tick(now=Date.now()){M.advance(state,Math.max(0,(now-lastTick)/1000),now);lastTick=now;}
function revealControls(){lastEdge=Date.now();document.body.classList.remove('ui-hidden');$('header').inert=false;$('controls').inert=false;}
function sync(){
 $('sound').textContent=state.soundEnabled?'Sound on':'Sound off';$('sound').setAttribute('aria-label',state.soundEnabled?'Mute ambient sound':'Enable ambient sound');$('sound').setAttribute('aria-pressed',String(state.soundEnabled));
 $('immersive').textContent=state.gardenOnly?'Keep UI':'Hide UI';$('immersive').setAttribute('aria-label',state.gardenOnly?'Keep controls visible':'Hide controls until edge hover');$('pin').textContent=state.pinned?'Pinned':'Pin';$('pin').setAttribute('aria-pressed',String(state.pinned));
 for(const key of ['daylightMode','cycleHour','daySpeed','weatherMode','seasonMode','volume','interval','duration','speed'])$(key).value=state[key];
 for(const key of ['southernHemisphere','lightningEnabled','soundEnabled','gardenOnly','reminders'])$(key).checked=state[key];
 $('cycleHour').disabled=state.daylightMode==='system';$('hour-output').textContent=formatHour(displayHour(Date.now()));$('undo').disabled=!backup;
 const sel=$('selected');sel.replaceChildren(new Option('Choose a flower',''));for(const f of state.flowers)sel.add(new Option(`${M.names[f.kind]} · ${f.age>=M.growTimes[f.kind]?`${M.headCount(f)} heads`:Math.floor(f.age/M.growTimes[f.kind]*100)+'%'}`,f.id));sel.value=selected;
 $('plant-actions').hidden=!state.flowers.some(f=>f.id===selected);
 $('plant-hint').hidden=planting===null;$('plant-hint').textContent=planting===null?'':`Click the moss to plant your ${M.names[planting].toLowerCase()}.`;
 $('plant-center').hidden=planting===null;document.body.classList.toggle('planting',planting!==null);
 for(const button of $('seeds').children)button.setAttribute('aria-pressed',String(Number(button.dataset.kind)===planting));
}
const formatHour=h=>`${String(Math.floor(h)).padStart(2,'0')}:${String(Math.floor(h%1*60)).padStart(2,'0')}`;
function prefs(){bridge?.configure({pinned:state.pinned,reminders:state.reminders,interval:state.interval,duration:state.duration});}
function rest(){hidden=true;audio.stop();document.body.classList.add('resting');$('resting').hidden=!!bridge;revealAt=Date.now()+state.interval*60000;hideAt=0;$('return-time').textContent=state.reminders?`Your garden returns in ${state.interval} minutes.`:'Return whenever you feel ready.';bridge?.rest();persist();}
function reveal(fromNative=false){hidden=false;document.body.classList.remove('resting');$('resting').hidden=true;hideAt=state.reminders?Date.now()+state.duration*1000:0;if(!fromNative)bridge?.reveal();revealControls();}
function addPlant(x,y){try{const f=M.plant(state,planting,x,y);selected=f.id;planting=null;message(`A new ${M.names[f.kind].toLowerCase()} begins.`);sync();persist();}catch(e){message(e.message);}}
for(let kind=0;kind<M.names.length;kind++){const b=document.createElement('button');b.dataset.kind=kind;b.textContent=`✿ ${M.names[kind]}`;b.setAttribute('aria-label',`Plant ${M.names[kind]}`);b.onclick=()=>{planting=planting===kind?null:kind;revealControls();sync();};$('seeds').append(b);}
$('scene').onclick=e=>{
 const r=e.currentTarget.getBoundingClientRect(),x=e.clientX-r.left,y=e.clientY-r.top;
 if(e.detail===3&&y<r.height*.42){$('god-controls').hidden=false;openSettings();message('God mode is awake.');return;}
 if(planting!==null){if(y<r.height*.54){message('Choose a patch of moss in the lower half of the garden.');return;}addPlant(x/r.width,y/r.height);}
 else{selected=renderer.pick(x,y)||'';if(selected)revealControls();sync();}
};
$('plant-center').onclick=()=>addPlant(.2+Math.random()*.6,.72+Math.random()*.18);
$('selected').onchange=()=>{selected=$('selected').value;sync();};
for(const action of ['boost','bloom','branch','remove'])$(action).onclick=()=>{const f=state.flowers.find(f=>f.id===selected);if(!f)return;tick();if(action==='remove'){state.flowers=state.flowers.filter(p=>p.id!==selected);selected='';}else f.age=action==='bloom'?Math.max(f.age,M.growTimes[f.kind]):f.age+(action==='boost'?600:M.growTimes[f.kind]);sync();persist();};
$('speed').onchange=()=>{tick();state.speed=Number($('speed').value);persist();};
$('sound').onclick=async()=>{await audio.unlock();state.soundEnabled=!state.soundEnabled;sync();persist();};
$('immersive').onclick=()=>{state.gardenOnly=!state.gardenOnly;revealControls();sync();persist();};
$('pin').onclick=()=>{state.pinned=!state.pinned;prefs();sync();persist();};
$('rest').onclick=rest;$('reveal').onclick=()=>reveal();
function openSettings(){revealControls();sync();$('settings').showModal();}
$('settings-open').onclick=openSettings;
$('settings').addEventListener('close',()=>{revealControls();persist();});
for(const key of ['daylightMode','cycleHour','daySpeed','weatherMode','seasonMode','southernHemisphere','lightningEnabled','soundEnabled','gardenOnly','reminders','volume','interval','duration']){
 $(key).addEventListener(['cycleHour','volume'].includes(key)?'input':'change',async()=>{
  const now=Date.now(),from=displayHour(now),previousWeather=displayWeather(now);tick(now);
  if(key==='soundEnabled')await audio.unlock();
  const el=$(key);let value=el.type==='checkbox'?el.checked:['range','number'].includes(el.type)||key==='daySpeed'?Number(el.value):el.value;
  if(key==='interval')value=M.clamp(value||15,1,1440);if(key==='duration')value=M.clamp(value||45,5,3600);
  if(key==='daylightMode'){state.cycleHour=from;lightTransition={from,at:now,duration:2000};}
  if(key==='cycleHour')lightTransition={from,at:now,duration:300};
  if(['weatherMode','seasonMode','southernHemisphere'].includes(key))weatherTransition={from:previousWeather,at:now};
  state[key]=value;
  if(['reminders','interval','duration'].includes(key)){prefs();hideAt=state.reminders?now+state.duration*1000:0;if(!state.reminders&&hidden)reveal();}
  sync();persist();
 });
}
function strike(now=Date.now()){strikes.push({at:now,delay:1800+Math.random()*6700,x:.18+Math.random()*.64,seed:Math.random()*1000,variant:Math.floor(Math.random()*3),strength:.65+Math.random()*.35,played:false});}
$('strike').onclick=()=>{state.weatherMode='storm';weatherTransition=null;strike();sync();persist();};
$('grow-all').onclick=()=>{tick();for(const f of state.flowers)f.age+=3600;sync();persist();};
$('reset').onclick=()=>{$('confirm-reset').showModal();};
$('confirm-reset').addEventListener('close',async()=>{
 if($('confirm-reset').returnValue!=='reset')return;tick();const before=structuredClone(state),oldBackup=backup;
 backup=structuredClone(state);M.reset(state);selected='';planting=null;
 try{await save();message('A fresh start. Your previous garden can be restored with Undo.');}catch{state=before;backup=oldBackup;message('Reset cancelled because the undo copy could not be saved.');}sync();
});
$('undo').onclick=()=>{if(backup){M.restore(state,backup);selected='';planting=null;sync();persist();message('Your previous garden has been restored.');}};
$('export').onclick=()=>{tick();const blob=new Blob([JSON.stringify(state,null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='stillgarden.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
$('import').onclick=()=>$('import-file').click();
$('import-file').onchange=async()=>{
 const file=$('import-file').files[0];if(!file)return;
 try{if(file.size>1024*1024)throw new Error('Choose a garden JSON file smaller than 1 MB.');const parsed=JSON.parse(await file.text()),next=M.normalize(parsed.state||parsed),before=structuredClone(state),oldBackup=backup;backup=before;state=next;tick();try{await save();}catch(e){state=before;backup=oldBackup;throw e;}selected='';planting=null;prefs();sync();message('Garden imported. Undo is available in Settings.');}catch(e){message(`Import failed: ${e.message}`);}
 $('import-file').value='';
};
if(platform.desktop){$('pin').hidden=!platform.canPin;document.querySelector('.window-actions').hidden=false;$('platform-note').textContent=platform.canPin?'Desktop edition · your garden is saved on this device.':'Desktop edition · this Wayland session controls window placement. Use your window manager’s “Keep above” option if available.';$('minimize').onclick=()=>bridge.minimize();$('close').onclick=()=>bridge.close();bridge.onReveal(()=>reveal(true));bridge.onRest(()=>{hidden=true;audio.stop();document.body.classList.add('resting');});bridge.onSave(()=>persist());document.addEventListener('click',e=>{const a=e.target.closest('a[href^="https:"]');if(a){e.preventDefault();bridge.openLink(a.href);}});prefs();}
else if('serviceWorker' in navigator&&location.protocol==='https:')navigator.serviceWorker.register('./sw.js').catch(()=>{});
// Pointer and keyboard users can always recover controls without moving a flower.
document.addEventListener('pointermove',e=>{const edge=e.clientX<24||e.clientY<24||e.clientX>innerWidth-24||e.clientY>innerHeight-24;if(edge||e.target.closest('.chrome'))revealControls();});
document.addEventListener('keydown',e=>{if(e.key==='Escape'){planting=null;sync();revealControls();}if(e.key==='Tab')revealControls();});
$('scene').addEventListener('keydown',e=>{if(e.key==='Enter'&&planting!==null){e.preventDefault();$('plant-center').click();}else if(e.key==='Enter')revealControls();});
$('scene').addEventListener('pointerdown',e=>{if(e.pointerType==='touch'&&document.body.classList.contains('ui-hidden'))revealControls();});
document.addEventListener('visibilitychange',()=>{tick();persist();if(document.hidden)audio.stop();else revealControls();});
window.addEventListener('pagehide',()=>{tick();persist();audio.stop();});
setInterval(()=>{const now=Date.now();tick(now);const mix=displayWeather(now),h=displayHour(now);
 audio.update(state,now,h,mix,hidden||document.hidden);
 if(!hidden&&mix.storm>.15){if(!nextStrike)nextStrike=now+3000+Math.random()*6000;if(now>=nextStrike){strike(now);nextStrike=now+14000+Math.random()*28000;}}else nextStrike=0;
 for(const s of strikes)if(!s.played&&now>=s.at+s.delay){s.played=true;if(state.soundEnabled&&!hidden&&!document.hidden)audio.oneShot(`thunder-${s.variant}`,s.strength*mix.storm,state.volume);}
 strikes=strikes.filter(s=>now-s.at<35000);
 if(!bridge&&state.reminders&&!$('settings').open){if(hidden&&now>=revealAt)reveal();else if(!hidden&&hideAt&&now>=hideAt)rest();}
 if(state.gardenOnly&&!$('settings').open&&planting===null&&!document.querySelector('.chrome :focus-visible')&&now-lastEdge>1800){document.body.classList.add('ui-hidden');$('header').inert=true;$('controls').inert=true;}
 if(now-lastSave>10000){lastSave=now;persist();sync();}
 $('weather-label').textContent=`${M.season(state)} · ${M.weatherName(state)} · ${formatHour(h)}`;
},200);
let lastFrame=0;function frame(now){requestAnimationFrame(frame);if(hidden||document.hidden||now-lastFrame<1000/30)return;lastFrame=now;const ms=Date.now();renderer.draw(state,ms,displayHour(ms),displayWeather(ms),strikes,document.body.classList.contains('ui-hidden')?'':selected);if(!ready){ready=true;bridge?.ready({flowers:state.flowers.length,canvas:!!renderer.c});}}
requestAnimationFrame(frame);sync();if(state.reminders)hideAt=Date.now()+state.duration*1000;
// Expose no privileged APIs: the garden lives entirely in the renderer sandbox.

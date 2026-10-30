const {app,BrowserWindow,ipcMain,Menu,Tray,nativeImage,protocol,net,shell,session}=require('electron');
const fs=require('node:fs/promises'),path=require('node:path'),{pathToFileURL}=require('node:url');
const ROOT=path.join(__dirname,'..'),WEB=path.join(ROOT,'web');
const smoke=process.argv.includes('--smoke-test');
const fsSync=require('node:fs');
if(smoke)app.setPath('userData',fsSync.mkdtempSync(path.join(require('node:os').tmpdir(),'stillgarden-smoke-')));
protocol.registerSchemesAsPrivileged([{scheme:'garden',privileges:{standard:true,secure:true,supportFetchAPI:true,stream:true}}]);
let win,tray,quitting=false,resting=false,timer=null,fadeTimer=null,queue=Promise.resolve(),prefs={pinned:true,reminders:false,interval:15,duration:45};
const canPin=!(process.platform==='linux'&&process.env.XDG_SESSION_TYPE==='wayland');
const saveFile=()=>path.join(app.getPath('userData'),'garden-portable.json');
const allowedLinks=new Set(['https://paradoxicalsw.com/','https://paradoxicalsw.com','https://github.com/paradoxicalsoftware/Stillgarden']);
const trusted=event=>event.sender===win?.webContents&&event.senderFrame===win.webContents.mainFrame&&event.senderFrame.url.startsWith('garden://app/');
function handle(name,fn){ipcMain.handle(name,(event,...args)=>{if(!trusted(event))throw new Error('Untrusted garden request');return fn(...args);});}
function listen(name,fn){ipcMain.on(name,(event,...args)=>{if(trusted(event))fn(...args);});}
function schedule(){clearTimeout(timer);if(!prefs.reminders)return;timer=setTimeout(()=>resting?reveal():rest(),resting?prefs.interval*60000:prefs.duration*1000);}
function fade(target,done){clearInterval(fadeTimer);if(process.platform==='linux'){done?.();return;}const from=win.getOpacity(),start=Date.now();fadeTimer=setInterval(()=>{if(win.isDestroyed()){clearInterval(fadeTimer);return;}const t=Math.min(1,(Date.now()-start)/1400);win.setOpacity(from+(target-from)*t*t*(3-2*t));if(t===1){clearInterval(fadeTimer);done?.();}},30);}
function rest(){if(!win||win.isDestroyed())return;resting=true;win.webContents.send('garden:rest');fade(0,()=>win.hide());schedule();}
function reveal(){if(!win||win.isDestroyed())return;resting=false;clearInterval(fadeTimer);win.show();win.setOpacity(1);win.webContents.send('garden:reveal');schedule();}
async function load(){try{return JSON.parse(await fs.readFile(saveFile(),'utf8'));}catch(e){if(e.code==='ENOENT')return null;throw new Error('Saved garden could not be read. Your original file has been kept.');}}
function save(value){
 if(typeof value!=='string'||Buffer.byteLength(value)>1024*1024)throw new Error('Invalid garden size');
 const parsed=JSON.parse(value);if(!parsed?.state||!Array.isArray(parsed.state.flowers)||parsed.state.flowers.length>30)throw new Error('Invalid garden');
 const task=queue.catch(()=>{}).then(async()=>{const file=saveFile();await fs.mkdir(path.dirname(file),{recursive:true});await fs.writeFile(file+'.tmp',value,{mode:0o600});await fs.rename(file+'.tmp',file);});queue=task;return task;
}
async function quit(){if(quitting)return;quitting=true;clearTimeout(timer);clearInterval(fadeTimer);win?.webContents.send('garden:save');await new Promise(resolve=>setTimeout(resolve,200));await queue.catch(()=>{});app.quit();}
if(!app.requestSingleInstanceLock()){app.quit();}else{
 app.on('second-instance',()=>reveal());
 app.whenReady().then(async()=>{
  protocol.handle('garden',request=>{
   const url=new URL(request.url);if(url.hostname!=='app')return new Response('Not found',{status:404});
   let pathname;try{pathname=decodeURIComponent(url.pathname);}catch{return new Response('Bad request',{status:400});}
   const file=path.resolve(WEB,'.'+(pathname==='/'?'/index.html':pathname));
   if(!file.startsWith(WEB+path.sep))return new Response('Forbidden',{status:403});
   return net.fetch(pathToFileURL(file).href);
  });
  session.defaultSession.setPermissionRequestHandler((_web,_permission,callback)=>callback(false));
  session.defaultSession.setPermissionCheckHandler(()=>false);
  // Desktop assets and code are bundled; only explicitly clicked links leave the app.
  session.defaultSession.webRequest.onBeforeRequest((details,callback)=>callback({cancel:!['garden:','devtools:','blob:'].includes(new URL(details.url).protocol)&&!(details.url.startsWith(pathToFileURL(WEB+path.sep).href))}));
  win=new BrowserWindow({width:680,height:680,minWidth:440,minHeight:500,frame:false,show:false,backgroundColor:'#e8eddf',icon:path.join(WEB,'assets/icon.png'),webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,backgroundThrottling:false}});
  win.setMenu(null);win.webContents.setWindowOpenHandler(()=>({action:'deny'}));
  win.webContents.on('will-navigate',(event,url)=>{if(!url.startsWith('garden://app/'))event.preventDefault();});
  win.on('close',event=>{if(!quitting){event.preventDefault();quit();}});
  win.on('ready-to-show',()=>{if(!smoke)win.show();});
  const icon=nativeImage.createFromPath(path.join(WEB,'assets/icon.png')).resize({width:24,height:24});
  if(!smoke){tray=new Tray(icon);tray.setToolTip('Stillgarden');tray.setContextMenu(Menu.buildFromTemplate([{label:'Show garden',click:reveal},{label:'Rest garden',click:rest},{type:'separator'},{label:'Paradoxical Software',click:()=>shell.openExternal('https://paradoxicalsw.com')},{label:'Quit Stillgarden',click:quit}]));tray.on('click',reveal);}
  handle('garden:load',load);handle('garden:save',save);
  handle('garden:platform',()=>({desktop:true,platform:process.platform,canPin}));
  handle('garden:configure',value=>{if(!value||typeof value!=='object')return;const previous=JSON.stringify(prefs);prefs={pinned:value.pinned===true,reminders:value.reminders===true,interval:Math.max(1,Math.min(1440,Number(value.interval)||15)),duration:Math.max(5,Math.min(3600,Number(value.duration)||45))};if(canPin)win.setAlwaysOnTop(prefs.pinned);if(previous!==JSON.stringify(prefs))schedule();});
  handle('garden:link',url=>{if(allowedLinks.has(url))return shell.openExternal(url);throw new Error('Unknown external link');});
  listen('garden:rest',rest);listen('garden:reveal',reveal);listen('garden:minimize',()=>win.minimize());listen('garden:close',quit);
  listen('garden:ready',async info=>{
   if(!smoke)return;
   try{
    if(!info.canvas||info.flowers!==3)throw new Error('Garden did not initialize');
    const prefs=win.webContents.getLastWebPreferences();if(!prefs.sandbox||!prefs.contextIsolation||prefs.nodeIntegration)throw new Error('Renderer isolation is missing');
    const imported=await import(pathToFileURL(path.join(WEB,'model.js')).href);const state=imported.freshState();await save(JSON.stringify({state,backup:null}));const loaded=await load();if(loaded.state.flowers.length!==3)throw new Error('Persistence failed');
    if(canPin){win.setAlwaysOnTop(true);if(!win.isAlwaysOnTop())throw new Error('Pinning failed');win.setAlwaysOnTop(false);}
    console.log('PASS: desktop renderer, preload bridge, isolated context, persistence and supported pinning');quitting=true;app.exit(0);
   }catch(error){console.error(error);app.exit(1);}
  });
  win.webContents.on('render-process-gone',(_event,details)=>{console.error('Renderer exited:',details.reason);if(smoke)app.exit(1);});
  if(smoke)setTimeout(()=>{console.error('Desktop smoke test timed out');app.exit(1);},30000).unref();
  await win.loadURL('garden://app/index.html');
 });
 app.on('activate',()=>reveal());app.on('window-all-closed',()=>app.quit());
 app.on('before-quit',event=>{if(!quitting){event.preventDefault();quit();}});
}

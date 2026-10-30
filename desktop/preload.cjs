const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('stillgarden',Object.freeze({
 load:()=>ipcRenderer.invoke('garden:load'),save:value=>ipcRenderer.invoke('garden:save',value),
 platform:()=>ipcRenderer.invoke('garden:platform'),configure:value=>ipcRenderer.invoke('garden:configure',value),
 rest:()=>ipcRenderer.send('garden:rest'),reveal:()=>ipcRenderer.send('garden:reveal'),
 minimize:()=>ipcRenderer.send('garden:minimize'),close:()=>ipcRenderer.send('garden:close'),
 openLink:url=>ipcRenderer.invoke('garden:link',url),ready:value=>ipcRenderer.send('garden:ready',value),
 onReveal:callback=>ipcRenderer.on('garden:reveal',()=>callback()),
 onRest:callback=>ipcRenderer.on('garden:rest',()=>callback()),
 onSave:callback=>ipcRenderer.on('garden:save',()=>callback())
}));

import {activity,season,isSnow,clamp} from './model.js';
export class Soundscape {
 constructor(){this.players=new Map();this.voices=[];this.nextOwl=0;this.unlocked=false;}
 async unlock(){this.unlocked=true;}
 player(name,loop=false){const p=new Audio(new URL(`./assets/${name}.mp3`,import.meta.url));p.loop=loop;p.preload='auto';return p;}
 oneShot(name,gain,volume){if(!this.unlocked)return;const p=this.player(name);p.volume=clamp(gain*volume);p.play().catch(()=>{});this.voices.push({p,gain});}
 update(s,now,hour,mix,hidden){
  const enabled=this.unlocked&&s.soundEnabled&&!hidden,day=activity(hour),sn=season(s,new Date(now));
  const gains={[`day-${sn}`]:day*(1-mix.rain*.7),[`night-${sn}`]:(1-day)*(1-mix.rain*.45),rain:isSnow(s,new Date(now))?0:mix.rain,wind:mix.wind};
  for(const [name,entry] of this.players){const target=enabled?(gains[name]||0)*s.volume:0;entry.p.volume+= (target-entry.p.volume)*.15;if(!enabled||((!gains[name])&&entry.p.volume<.001)){entry.p.pause();if(!(name in gains))this.players.delete(name);}}
  if(enabled)for(const [name,gain] of Object.entries(gains)){if(gain<.001)continue;if(!this.players.has(name)){const p=this.player(name,true);p.volume=0;this.players.set(name,{p});}const p=this.players.get(name).p;if(p.paused)p.play().catch(()=>{});}
  for(const v of this.voices){if(!enabled)v.p.pause();else v.p.volume=clamp(v.gain*s.volume);}this.voices=this.voices.filter(v=>!v.p.ended&&!v.p.paused);
  if(!enabled||day>.9){this.nextOwl=0;return;}
  if(!this.nextOwl)this.nextOwl=now+6000+Math.random()*14000;
  if(now>=this.nextOwl){this.oneShot('owl-call',(1-day)*(1-mix.rain*.65)*(.6+Math.random()*.4),s.volume);this.nextOwl=now+32000+Math.random()*43000;}
 }
 stop(){for(const {p} of this.players.values())p.pause();for(const {p} of this.voices)p.pause();this.voices=[];}
}

// Platform-independent garden rules. Seconds and UTC epoch milliseconds at boundaries.
export const names = ['Daisy','Poppy','Cosmos','Lavender','Sunflower','Cornflower','Marigold','Tulip','Coneflower','Bluebell'];
export const growTimes = [1200,1800,2400,2700,3600,2100,1500,2700,3000,2400];
export const colors = ['#fcf5d1','#ef5940','#e891ad','#a38cd4','#ffc238','#5991ed','#ff8c24','#f25c8f','#c778c2','#737ade'];
export const habits = [
 [112,5,true,42],[138,4,false,48],[145,7,false,55],[170,7,true,42],[166,4,false,50],
 [126,6,false,43],[95,7,false,49],[130,3,true,27],[145,4,true,43],[130,3,true,32]
];
export const clamp = (x,a=0,b=1) => Math.min(b,Math.max(a,x));
export const smooth = x => { const t=clamp(x); return t*t*(3-2*t); };
export const wrap = (x,n=24) => ((x%n)+n)%n;
export const daylight = h => smooth((Math.cos((h-12)*Math.PI/12)+.18)/.95);
export const activity = h => smooth((daylight(h)-.08)/.55);
export const lifeStage = age => { const t=wrap(age,2400); return t<800?0:t<1400?1:2; };
export const headCount = f => 1+Math.min(habits[f.kind][1]-1,Math.floor(Math.max(0,f.age/growTimes[f.kind]-1)));
export const calendarSeason = (date,south=false) => ['winter','spring','summer','autumn'][(Math.floor((date.getMonth()+1)%12/3)+(south?2:0))%4];
export const season = (s,date=new Date()) => s.seasonMode==='calendar'?calendarSeason(date,s.southernHemisphere):s.seasonMode;
export function automaticWeather(slot,seasonName) {
 const hash=BigInt.asUintN(64,BigInt(slot)*6364136223846793005n+1442695040888963407n);
 const value=Number((hash>>32n)%100n), chance=seasonName==='summer'?8:seasonName==='winter'?1:4;
 return value<chance?'storm':value<(['spring','autumn'].includes(seasonName)?28:20)?(seasonName==='winter'?'snow':'rain'):value<43?'windy':value<72?'calm':'clear';
}
export const weatherName = (s,date=new Date()) => s.weatherMode==='auto'?automaticWeather(Math.floor(date.getTime()/480000),season(s,date)):(s.weatherMode==='rain'&&season(s,date)==='winter'?'snow':s.weatherMode);
export const weatherMix = name => name==='storm'?{rain:1,wind:.9,storm:1}:['rain','snow'].includes(name)?{rain:.65,wind:.35,storm:0}:{rain:0,wind:name==='windy'?.85:name==='calm'?.03:.12,storm:0};
export const blend = (a,b,t) => Object.fromEntries(Object.keys(b).map(k=>[k,a[k]+(b[k]-a[k])*smooth(t)]));
export const isSnow = (s,date=new Date()) => season(s,date)==='winter'||weatherName(s,date)==='snow';
export function weather(s,ms=Date.now()) {
 const date=new Date(ms), target=weatherMix(weatherName(s,date));
 return s.weatherMode==='auto'?blend(weatherMix(automaticWeather(Math.floor(ms/480000)-1,season(s,date))),target,(ms%480000)/25000):target;
}
export function hour(s,ms=Date.now(),extra=0) {
 const date=new Date(ms);
 return s.daylightMode==='system'?date.getHours()+date.getMinutes()/60+date.getSeconds()/3600+date.getMilliseconds()/3600000:wrap(s.cycleHour+(s.daylightMode==='cycle'?extra*s.daySpeed/3600:0));
}
export const temperature = (seasonName,h,snowfall) => {
 const value=({winter:-5,summer:18,spring:7,autumn:4}[seasonName])+daylight(h)*9;
 return snowfall>.02?Math.min(-1,value):value;
};
export const snowDepth = (current,seconds,snowfall,temp,exposed=false) => clamp(current+seconds*(snowfall/(exposed?150:360)-Math.max(0,temp)*(exposed?.00020:.00009)));
const flower=(kind,x,y,age=0)=>({id:crypto.randomUUID(),kind,x,y,age,snow:0});
export function freshState(now=Date.now()) {
 return {schema:1,flowers:[flower(0,.29,.80,1200),flower(2,.53,.76,1750),flower(4,.70,.85,2900)],speed:1,pinned:true,reminders:false,interval:15,duration:45,soundEnabled:false,volume:.22,gardenOnly:true,wildlifeAge:0,daylightMode:'system',cycleHour:12,daySpeed:60,weatherMode:'auto',seasonMode:'calendar',southernHemisphere:false,lightningEnabled:true,groundSnow:0,savedAt:now};
}
const finite=(v,fallback,min,max)=>typeof v==='number'&&Number.isFinite(v)?clamp(v,min,max):fallback;
export function normalize(input,now=Date.now()) {
 if(!input||typeof input!=='object'||!Array.isArray(input.flowers)) throw new Error('This file is not a Stillgarden save.');
 const s=freshState(now);
 for(const key of ['pinned','reminders','soundEnabled','gardenOnly','southernHemisphere','lightningEnabled']) if(typeof input[key]==='boolean')s[key]=input[key];
 for(const [key,options] of Object.entries({daylightMode:['system','manual','cycle'],weatherMode:['auto','clear','calm','windy','rain','storm','snow'],seasonMode:['calendar','spring','summer','autumn','winter']})) if(options.includes(input[key]))s[key]=input[key];
 for(const [key,min,max] of [['speed',0,1000],['interval',1,1440],['duration',5,3600],['volume',0,1],['wildlifeAge',0,1e12],['cycleHour',0,24],['daySpeed',1,3600],['groundSnow',0,1]])s[key]=finite(input[key],s[key],min,max);
 const ids=new Set();
 s.flowers=input.flowers.slice(0,30).filter(f=>f&&Number.isInteger(f.kind)&&f.kind>=0&&f.kind<10).map(f=>{
  const id=typeof f.id==='string'&&f.id.length<80&&!ids.has(f.id)?f.id:crypto.randomUUID();ids.add(id);
  return {id,kind:f.kind,x:finite(f.x,.5,.08,.92),y:finite(f.y,.8,.58,.94),age:finite(f.age,0,0,1e12),snow:finite(f.snow,0,0,1)};
 });
 // Swift's JSONEncoder uses seconds since 2001; our portable format uses epoch milliseconds.
 const stamp=typeof input.savedAt==='string'?Date.parse(input.savedAt):input.savedAt;
 s.savedAt=finite(stamp,now,0,now);
 if(!input.schema&&typeof input.savedAt==='number'&&input.savedAt<1e10)s.savedAt=(input.savedAt+978307200)*1000;
 return s;
}
export function advance(s,seconds,end=Date.now()) {
 if(!Number.isFinite(seconds)||seconds<=0)return;
 const preferred=s.daylightMode==='cycle'?clamp(3600/s.daySpeed,1,120):120;
 const steps=Math.min(2880,Math.max(1,Math.ceil(seconds/preferred))),dt=seconds/steps;
 for(let i=0;i<steps;i++){
  const offset=(i+.5)*dt,date=new Date(end-seconds*1000+offset*1000), sn=season(s,date);
  const falling=isSnow(s,date)?weatherMix(weatherName(s,date)).rain:0;
  const temp=temperature(sn,hour(s,date.getTime(),offset),falling);
  s.groundSnow=snowDepth(s.groundSnow,dt,falling,temp);
  for(const f of s.flowers)f.snow=snowDepth(f.snow,dt,falling,temp,true);
 }
 s.wildlifeAge+=seconds*s.speed;
 for(const f of s.flowers)f.age+=seconds*s.speed;
 if(s.daylightMode==='cycle')s.cycleHour=wrap(s.cycleHour+seconds*s.daySpeed/3600);
 s.savedAt=end;
}
export function plant(s,kind,x,y){if(s.flowers.length>=30)throw new Error('Your garden is full. Remove a flower to make room.');const f=flower(kind,clamp(x,.08,.92),clamp(y,.58,.94));s.flowers.push(f);return f;}
export function reset(s){const backup=structuredClone(s);s.flowers=[];s.groundSnow=0;s.wildlifeAge=0;return backup;}
export function restore(s,backup){s.flowers=structuredClone(backup.flowers);s.groundSnow=backup.groundSnow;s.wildlifeAge=backup.wildlifeAge;}

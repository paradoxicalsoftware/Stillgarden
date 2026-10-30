import {colors,habits,growTimes,clamp,daylight,activity,lifeStage,season,isSnow} from './model.js';
const tau=Math.PI*2, ink='#2e4533';
function ellipse(c,x,y,rx,ry,color){c.beginPath();c.ellipse(x,y,Math.max(.01,rx),Math.max(.01,ry),0,0,tau);c.fillStyle=color;c.fill();}
function line(c,points,color,width=1){c.beginPath();c.moveTo(...points[0]);for(const p of points.slice(1))c.lineTo(...p);c.strokeStyle=color;c.lineWidth=width;c.stroke();}
function gradient(c,x,y,x2,y2,a,b){const g=c.createLinearGradient(x,y,x2,y2);g.addColorStop(0,a);g.addColorStop(1,b);return g;}
function head(c,kind,bloom,radius){
 const r=radius*bloom;if(bloom<.08){ellipse(c,0,-1,3,5,'#668738');return;}
 if(kind===3){
  const length=46*bloom;line(c,[[0,0],[0,-length]],'#6b7b57',1.1);
  for(let tier=0;tier<10;tier++)for(const side of [-1,1]){
   const x=side*(2.3+2.5*(1-tier*.065)),y=-tier*length/10;
   c.beginPath();c.moveTo(0,y+2);c.quadraticCurveTo(x*2,y+3,x*1.6,y-4);c.quadraticCurveTo(x,y-7,0,y+2);c.fillStyle=gradient(c,x,y-5,0,y+2,'#c4ade3','#644794');c.fill();
  }return;
 }
 if(kind===7){
  for(let layer=0;layer<2;layer++)for(let n=-1;n<=1;n++){
   const x=n*r*.35;c.beginPath();c.moveTo(0,6);c.bezierCurveTo(-r*.8,-r*.1,x-r*.45,-r,x-r*.35,-r*1.3);c.quadraticCurveTo(x,-r*1.6,x+r*.35,-r*1.3);c.bezierCurveTo(x+r*.5,-r*.8,r*.7,0,0,6);c.fillStyle=gradient(c,x-5,-r,8,8,colors[kind],'#94294d');c.fill();
   c.beginPath();c.moveTo(x,-r*1.15);c.quadraticCurveTo(x+3,-r*.4,0,3);c.strokeStyle='#ffffff22';c.lineWidth=.6;c.stroke();
  }return;
 }
 if(kind===9){
  c.beginPath();c.moveTo(0,8);c.quadraticCurveTo(-6,-36*bloom,12,-40*bloom);c.strokeStyle='#476635';c.lineWidth=1.4;c.stroke();
  for(let n=0;n<5;n++){
   const x=2+n*2,y=-n*8*bloom;c.beginPath();c.moveTo(x-4,y-4);c.quadraticCurveTo(x+6,y-10,x+6,y);c.stroke();
   c.beginPath();c.moveTo(x+3,y);c.bezierCurveTo(x-1,y+4,x+4,y+9,x+1,y+12*bloom);c.quadraticCurveTo(x+7,y+17*bloom,x+14,y+12*bloom);c.bezierCurveTo(x+10,y+7,x+12,y+3,x+8,y);c.closePath();c.fillStyle=gradient(c,x,y,x+14,y+10,'#a8a6f0','#474096');c.fill();
  }return;
 }
 if(kind===8){
  for(let n=0;n<12;n++){const a=n*tau/12,x=Math.cos(a)*r,y=8+Math.abs(Math.sin(a))*r*.8;c.beginPath();c.moveTo(Math.cos(a)*5,Math.sin(a)*3);c.quadraticCurveTo(x*.6-5,y*.6,x,y);c.quadraticCurveTo(x*.6+5,y*.6+4,Math.cos(a)*5,Math.sin(a)*3);c.fillStyle=gradient(c,0,0,x,y,colors[kind],'#7d4070');c.fill();}
  ellipse(c,0,-4*bloom,9*bloom,8*bloom,'#9c5c27');for(let n=0;n<35;n++){const a=n*2.399,d=Math.sqrt(n/35)*7*bloom;ellipse(c,Math.cos(a)*d,-4+Math.sin(a)*d*.7,.6,.85,'#e19c42');}return;
 }
 const petals=kind===0?21:kind===1?4:kind===2?8:kind===4?28:kind===5?16:15,layers=kind===6?5:[4,5].includes(kind)?2:1;
 for(let layer=0;layer<layers;layer++)for(let n=0;n<petals;n++){
  c.save();c.rotate(n*tau/petals+layer*.17);const len=r*(1-layer*.14)*(1+.055*Math.sin(n*7.13+kind)),w=len*(kind===1?.94:kind===2?.35:kind===6?.26:.14);
  c.beginPath();c.moveTo(-1,-2);c.bezierCurveTo(-w*.6,-len*.3,-w*1.1,-len*.6,-w,-len*.82);
  if(kind===5)for(const p of [[-w*.9,-len*1.07],[-w*.3,-len*.92],[0,-len*1.13],[w*.4,-len*.95],[w,-len*1.04]])c.lineTo(...p);
  else c.quadraticCurveTo(0,-len*(kind===1?1.2:1.08),w,-len*.82);
  c.bezierCurveTo(w*1.1,-len*.6,w*.5,-len*.25,1,-2);c.closePath();c.fillStyle=gradient(c,-w,-len,0,3,colors[kind],kind===0?'#c0b68d':colors[kind]+'bb');c.fill();
  line(c,[[0,-len*.9],[1,-len*.4],[0,-5]],'#ffffff38',.45);c.restore();
 }
 const core=r*(kind===4?.43:kind===1?.23:kind===6?.12:.22);ellipse(c,0,0,core,core*.82,[4,1].includes(kind)?'#63451e':'#e1ab35');
 for(let n=0;n<55;n++){const a=n*2.399,d=Math.sqrt(n/55)*core*.92;ellipse(c,Math.cos(a)*d,Math.sin(a)*d*.8,.45,.45,'#ffde6388');}
}
function snowCap(c,kind,radius,bloom,depth){
 if(depth<.005||bloom<.08)return;const r=radius*bloom;
 if(kind===3){for(let tier=0;tier<10;tier++)ellipse(c,0,-tier*4.6*bloom-2,(4.5-tier*.22)*depth,1+depth,'#f5faff');}
 else if(kind===9){for(let n=0;n<5;n++)ellipse(c,7+n*2,-n*8*bloom-1,4.5*depth,1.5*depth,'#f5faff');}
 else{const top=kind===7?-r*1.32:kind===8?-12*bloom:-r*.90,w=(kind===8?9*bloom:r*(kind===7?.68:.82))*Math.sqrt(depth);c.beginPath();c.moveTo(-w,top+3);c.quadraticCurveTo(0,top-7*depth,w,top+3);c.quadraticCurveTo(0,top+3+7*depth,-w,top+3);c.fillStyle=gradient(c,0,top-3,0,top+7,'#f5faff','#cddfe8');c.fill();}
}
export function flowerGeometry(f,time,wind){
 const kind=f.kind,p=f.age/growTimes[kind],[h,maxHeads,basal,spread]=habits[kind],m=clamp(Math.log1p(Math.max(0,p-1))/2.5),height=12+(h-12)*Math.min(1,p*1.6)+26*m,sway=Math.sin(time*.8+f.x*20)*(1+wind*5);
 const heads=[{x:sway,y:-height,g:clamp((p-.36)/.64),r:(kind===4?27:kind===1?23:21)+m*4}],stems=[{x:0,y:0,end:heads[0],width:kind===4?3.5:kind===3?1.4:2}];
 for(let n=0;n<maxHeads-1;n++){const g=clamp(p-n-1);if(!g)continue;const side=n%2===0?-1:1,fraction=(Math.floor(n/2)+1)/Math.floor((maxHeads+1)/2),root={x:basal?side*3:0,y:basal?-3:-height*(.33+n*.065)},target=-height*(basal?.78+.12*Math.sin(n*2):.67+.12*Math.sin(n*1.8));const end={x:side*spread*(.45+fraction*.55)*g+sway,y:root.y+(target-root.y)*g,g,r:[3,9].includes(kind)?19:kind===7?20:15+m*3};heads.push(end);stems.push({...root,end,width:kind===3?1.2:1.6});}
 return {heads,stems,height,p};
}
function drawFlower(c,f,time,wind,selected){
 const kind=f.kind,{heads,stems,height,p}=flowerGeometry(f,time,wind),green=kind===3?'#647b5c':'#476631';
 if(selected){c.beginPath();c.ellipse(0,2,22,6,0,0,tau);c.strokeStyle='#ffffffe0';c.lineWidth=1;c.stroke();}
 for(const stem of stems){const e=stem.end;c.beginPath();c.moveTo(stem.x,stem.y);c.bezierCurveTo(stem.x+(e.x-stem.x)*.25,stem.y-(stem.y-e.y)*.4,e.x-2,e.y+20,e.x,e.y);c.strokeStyle=green;c.lineWidth=stem.width;c.stroke();}
 const leaves=kind===3?12:[7,9].includes(kind)?5:6;
 for(let n=0;n<leaves;n++){
  const side=n%2===0?-1:1,basal=[0,3,7,9].includes(kind),y=basal?-Math.floor(n/2)*5:-height*(.16+n*.095),len=([7,9].includes(kind)?65:kind===3?30:31)*Math.min(1,p*2),ex=side*len*(basal?.5:.85),ey=y-len*(basal?.95:.55),w=[3,5,9].includes(kind)?3:kind===7?12:kind===4?15:8;
  if([1,2,6].includes(kind)){line(c,[[0,y],[ex,ey]],green);for(let k=1;k<6;k++)for(const d of [-1,1]){const x=ex*k/6,yy=y+(ey-y)*k/6;line(c,[[x,yy],[x+side*9,yy+d*(kind===2?8:5)-4]],green,kind===2?.8:2.3);}}
  else{c.beginPath();c.moveTo(0,y);c.quadraticCurveTo(ex-side*w,y-w,ex,ey);c.quadraticCurveTo(side*w,ey+w,0,y);c.fillStyle=gradient(c,0,y,ex,ey,green,'#829c57');c.fill();line(c,[[0,y],[ex,ey]],'#ffffff2e',.5);}
 }
 for(const b of [...heads].reverse()){c.save();c.translate(b.x,b.y);head(c,kind,b.g,b.r);snowCap(c,kind,b.r,b.g,f.snow);c.restore();}
}
function wildlife(c,w,h,t,age,hour){
 const a=activity(hour);
 for(let i=0;i<3;i++){
  const phase=t*.38+i*2.1,rx=w*(.19+i*.29),ry=h*(.84+i%2*.05),x=rx+(w*(.5+.31*Math.sin(phase))-rx)*a,y=ry+(h*(.52+.13*Math.sin(phase*1.7+i))-ry)*a,face=Math.cos(phase)<0?-1:1;
  c.save();c.translate(x,y);c.scale(a>.05?face:1,1);c.rotate(Math.cos(phase)*.2*face*a);const wing=2+a*(2+Math.abs(Math.sin(t*24+i))*5);for(const d of [-1,1])ellipse(c,d*3,-wing/2-3,4,wing/2,'#ffffffb3');ellipse(c,0,.5,8,4.5,'#f5b838');for(const n of [-3,2])line(c,[[n,-3],[n,4]],'#373626',2);ellipse(c,8.5,0,2.5,3,'#303321');c.restore();
 }
 for(let i=0;i<3;i++){
  const stage=lifeStage(age+i*800),ox=w*(.25+i*.24),oy=h*(.79+i%2*.08);
  if(stage===0){const x=ox+Math.sin(t*.12+i)*24;for(let n=0;n<7;n++){const y=oy+Math.sin(t*2-n*.8)*1.8;ellipse(c,x+n*4+3.5,y+3.5,3.5,3.5,`rgb(${158-n*6},189,82)`);line(c,[[x+n*4+3,y+5],[x+n*4+2,y+9]],ink,.8);}ellipse(c,x+29,oy+2,1,1,ink);}
  else if(stage===1){c.beginPath();c.moveTo(ox-20,oy+17);c.quadraticCurveTo(ox-25,oy-20,ox+8,oy-27);c.strokeStyle='#5c6636';c.lineWidth=2;c.stroke();const x=ox+Math.sin(t*.7)*1.2;line(c,[[ox+8,oy-27],[x+8,oy-20]],'#ffffff99',.7);ellipse(c,x+7.5,oy-7.5,7.5,13.5,gradient(c,x,oy-21,x+15,oy+6,'#c4cf78','#5c7d3b'));for(let n=0;n<4;n++)line(c,[[x+2,oy-14+n*4],[x+12,oy-12+n*4]],'#ffffff4d',.7);}
  else{
   const rx=w*(.23+i*.26),ry=h*(.72+i%2*.08),x=rx+(w*(.5+.34*Math.sin(t*.22+i*2))-rx)*a,y=ry+(h*(.35+.16*Math.cos(t*.31+i))-ry)*a,flap=.12+a*(.18+.7*Math.abs(Math.sin((t+i)*5)));
   c.save();c.translate(x,y);c.rotate(Math.sin((t+i)*.8)*.3*a);for(const side of [-1,1]){c.save();c.scale(side*flap,1);for(const [yy,ww,hh] of [[-15,18,20],[0,13,14]]){ellipse(c,1+ww/2,yy+hh/2,ww/2,hh/2,['#f2a847','#87baed','#e8bff2'][i]);c.strokeStyle=ink;c.lineWidth=1.5;c.stroke();ellipse(c,ww*.5+2,yy+7.5,2,2.5,'#ffffffcc');}c.restore();}ellipse(c,0,2,1.8,11,ink);for(const side of [-1,1])line(c,[[0,-8],[side*2,-16],[side*5,-17]],ink,.8);c.restore();
  }
 }
}
export class Renderer {
 constructor(canvas){this.canvas=canvas;this.c=canvas.getContext('2d');this.image=new Image();this.image.src=new URL('./assets/garden.jpg',import.meta.url).href;this.hit=[];}
 draw(s,now,hour,mix,strikes,selected){
  const bounds=this.canvas.getBoundingClientRect(),w=bounds.width,h=bounds.height,dpr=Math.min(2,devicePixelRatio||1),c=this.c;
  if(this.canvas.width!==Math.round(w*dpr)||this.canvas.height!==Math.round(h*dpr)){this.canvas.width=Math.round(w*dpr);this.canvas.height=Math.round(h*dpr);}
  c.setTransform(dpr,0,0,dpr,0,0);c.clearRect(0,0,w,h);c.lineCap='round';c.fillStyle='#647653';c.fillRect(0,0,w,h);
  if(this.image.complete&&this.image.naturalWidth){const scale=Math.max(w/this.image.width,h/this.image.height);c.drawImage(this.image,(w-this.image.width*scale)/2,(h-this.image.height*scale)/2,this.image.width*scale,this.image.height*scale);}
  const sn=season(s,new Date(now)),t=now/1000,scale=clamp(w/640,.6,1.25);
  c.save();c.globalCompositeOperation=sn==='winter'?'screen':'soft-light';c.fillStyle={winter:'#bacfe34d',autumn:'#bf6b1f3d',spring:'#94c75414',summer:'#dec25714'}[sn];c.fillRect(0,0,w,h);c.restore();
  if(s.groundSnow>.005){const depth=s.groundSnow;c.save();c.globalAlpha=Math.sqrt(depth)*.85;c.fillStyle=gradient(c,0,h*.65,0,h,'#e5eef244','#f4faff');c.beginPath();c.moveTo(0,h);c.lineTo(0,h*.72);for(let x=0;x<=w+12;x+=12)c.lineTo(x,h*(.72+.015*Math.sin(x*.018))-(depth*9));c.lineTo(w,h);c.closePath();c.fill();for(let n=0;n<65;n++){const x=(n*117.13)%w,y=h*(.73+(n*7.93%1)*.25);ellipse(c,x,y,(8+n%7)*depth,(2+n%4)*depth,'#f4faffbb');}c.restore();}
  this.hit=[];
  for(const f of [...s.flowers].sort((a,b)=>a.y-b.y)){const x=f.x*w,y=f.y*h;c.save();c.translate(x,y);c.scale(scale,scale);drawFlower(c,f,t,mix.wind,selected===f.id);c.restore();this.hit.push({id:f.id,x,y,top:y-flowerGeometry(f,t,mix.wind).height*scale,scale});}
  wildlife(c,w,h,t,s.wildlifeAge,hour);
  const day=daylight(hour),dusk=Math.exp(-(((hour-18.2)/1.5)**2))+Math.exp(-(((hour-5.8)/1.5)**2));
  c.fillStyle=`rgba(6,14,46,${(1-day)*.72})`;c.fillRect(0,0,w,h);c.fillStyle=gradient(c,0,0,0,h,`rgba(235,117,64,${dusk*.24})`,'#eb754000');c.fillRect(0,0,w,h);
  c.save();c.globalAlpha=(1-day)**3*.7;for(let n=0;n<40;n++){const x=Math.abs(Math.sin(n*127.1)*43758.5453%1)*w,y=Math.abs(Math.sin(n*311.7)*23421.631%1)*h*.36;ellipse(c,x,y,n%4===0?1.1:.6,n%4===0?1.1:.6,'#e0e8ff');}c.globalAlpha=(1-day)**4*.8;c.shadowColor='#ffffff66';c.shadowBlur=15;ellipse(c,w*.77,h*.13,11.5,11.5,'#dee6f0');c.restore();
  c.fillStyle=`rgba(31,43,56,${mix.rain*.19+mix.storm*.10})`;c.fillRect(0,0,w,h);
  if(mix.rain>.005)for(let n=0;n<150;n++){
   if(isSnow(s,new Date(now))){const depth=.45+(n%7)/7,x=(n*73.13+t*12*depth+Math.sin(t*.45+n)*18+mix.wind*20*Math.sin(t*.3))%(w+60)-30,y=(n*47.73+t*23*depth)%(h+40)-20,r=1.1+depth*1.7;ellipse(c,x,y,r,r,`rgba(255,255,255,${mix.rain*(.35+depth*.35)})`);}
   else{const x=(n*73.13+t*54+mix.wind*16*Math.sin(t*.3))%(w+60)-30,y=(n*47.73+t*310)%(h+40)-20;line(c,[[x,y],[x+mix.wind*5,y+9+mix.storm*7]],`rgba(207,222,237,${mix.rain*.38})`,.7);}
  }
  for(let n=0;n<9;n++){const x=(n*93+t*26+mix.wind*12*Math.sin(t*.4))%(w+50)-25,y=h*(.28+n*.065)+Math.sin(t*.6+n)*16;c.save();c.globalAlpha=mix.wind*.65;c.translate(x,y);c.rotate(t*.7+n);ellipse(c,0,0,3,1.3,sn==='autumn'?'#c26e2b':sn==='winter'?'#fff':'#94ab4a');c.restore();}
  if(s.lightningEnabled)for(const strike of strikes){const age=(now-strike.at)/1000,pulse=age>=0?Math.exp(-age*7)*(1-Math.exp(-age*60))*strike.strength:0;if(pulse<.002)continue;c.save();c.globalAlpha=pulse;c.fillStyle='#cddfff38';c.fillRect(0,0,w,h);const points=[[w*strike.x,0]];for(let step=1;step<=9;step++){const x=w*strike.x+Math.sin(strike.seed+step*8.3)*w*.035,y=h*step*.034;points.push([x,y]);if([3,6].includes(step))line(c,[[x,y],[x+w*.045,y+h*.025],[x+w*.03,y+h*.07]],'#ffffff99');}line(c,points,'#a1c4ff4d',7);line(c,points,'#fff',1.8);c.restore();}
 }
 pick(x,y){return [...this.hit].reverse().find(f=>Math.abs(f.x-x)<55*f.scale&&y>f.top-35*f.scale&&y<f.y+10)?.id;}
}

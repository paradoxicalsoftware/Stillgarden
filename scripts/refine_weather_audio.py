"""Rebuild owl-free night beds, a CC0 owl one-shot, and distinct thunder one-shots."""
import numpy as np, wave
from pathlib import Path
root=Path(__file__).resolve().parent.parent
out=root/'Resources'
(root/'work').mkdir(exist_ok=True)
sr=22050

def colored(rng,count,low,high,power):
 f=np.fft.rfftfreq(count,1/sr);shape=np.maximum(f,low)**(-power)*np.exp(-(f/high)**2);shape[f<low]=0
 a=np.fft.irfft((rng.normal(size=len(f))+1j*rng.normal(size=len(f)))*shape,n=count)
 return a/np.std(a)
def save(name,a):
 if a.ndim==1:a=np.stack([a,np.roll(a,73)*.94],axis=1)
 count=len(a);fade=np.minimum(1,np.minimum(np.arange(count),np.arange(count)[::-1])/(sr*.08))
 a=a*fade[:,None];assert np.max(np.abs(a))<.95
 with wave.open(str(out/(name+'.wav')),'wb') as w:
  w.setnchannels(2);w.setsampwidth(2);w.setframerate(sr);w.writeframes((a*32767).astype('<i2').tobytes())
 print(name,round(count/sr,2),round(float(np.max(np.abs(a))),3))
for idx,season in enumerate(['spring','summer','autumn','winter']):
 rng=np.random.default_rng(512+idx);n=sr*60;t=np.arange(n)/sr
 night=colored(rng,n,80,4500,.8)*.009
 if idx!=3:
  for freq,rate in [(3900,1.7),(4700,1.13),(5200,.83)]:
   night+=.012*(.5 if idx==2 else 1)*np.maximum(0,np.sin(2*np.pi*rate*t))**10*np.maximum(0,np.sin(2*np.pi*31*t))**4*np.sin(2*np.pi*freq*t)
 save('night-'+season,night)
# Decode the public-domain recording with the system audio converter.
import subprocess,tempfile
with tempfile.TemporaryDirectory(dir=root/'work') as folder:
 decoded=Path(folder)/'owl.wav'
 subprocess.run(['afconvert',str(root/'SourceAudio/owl-source.mp3'),str(decoded),'-f','WAVE','-d','LEI16@22050'],check=True)
 with wave.open(str(decoded),'rb') as f:
  owl=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float).reshape(-1,f.getnchannels())/32768
 owl-=owl.mean(axis=0)
 # Remove low phone-handling rumble while retaining the original call's timbre.
 freq=np.fft.rfftfreq(len(owl),1/sr)
 filt=(1-np.exp(-(freq/130)**4))*np.exp(-(freq/4500)**4)
 owl=np.fft.irfft(np.fft.rfft(owl,axis=0)*filt[:,None],n=len(owl),axis=0)
 owl*=.16/max(.001,np.max(np.abs(owl)))
 if owl.shape[1]==1:owl=np.repeat(owl,2,axis=1)
 save('owl-call',owl)
for k,duration in enumerate([12,16,20]):
 rng=np.random.default_rng(1700+k);n=sr*duration;t=np.arange(n)/sr
 rumble=colored(rng,n,23,420-k*60,1.0)
 env=(1-np.exp(-t*(4-k)))*np.exp(-t*(.33-k*.05))
 rolls=sum(np.exp(-((t-center)/width)**2)*amp for center,width,amp in [(2.1,1.2,.3),(5+k,1.7,.45),(8+k,2,.22)])
 air=colored(rng,n,250,2200,.7)*np.exp(-t*1.6)*.012
 a=rumble*(env+rolls)*.065+air
 save('thunder-'+str(k),a)

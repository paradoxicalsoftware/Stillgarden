"""Original procedural seasonal wildlife and weather loops (no downloaded recordings)."""
import numpy as np, wave
from pathlib import Path
sr=22050; seconds=60; n=sr*seconds; t=np.arange(n)/sr
out=Path(__file__).resolve().parent.parent/'Resources'

def noise(rng,low,high,power):
    f=np.fft.rfftfreq(n,1/sr)
    shape=np.maximum(f,low)**(-power)*np.exp(-(f/high)**2)
    shape[f<low]=0
    a=np.fft.irfft((rng.normal(size=len(f))+1j*rng.normal(size=len(f)))*shape,n=n)
    return a/np.std(a)

def save(name,a):
    a=np.asarray(a)
    if a.ndim==1: a=np.stack([a,np.roll(a,87)*.93],axis=1)
    peak=np.max(np.abs(a)); assert peak<.95,(name,peak)
    # Fade the loop boundary very briefly to avoid clicks.
    ramp=np.minimum(1,np.minimum(np.arange(n),np.arange(n)[::-1])/(sr*.06))
    a*=ramp[:,None]
    with wave.open(str(out/(name+'.wav')),'wb') as w:
        w.setnchannels(2);w.setsampwidth(2);w.setframerate(sr);w.writeframes((a*32767).astype('<i2').tobytes())
    print(name,round(float(peak),3))

for season,idx in [('spring',0),('summer',1),('autumn',2),('winter',3)]:
    rng=np.random.default_rng(120+idx)
    a=noise(rng,100,5000,.7)*.012
    # Four song families: descending whistles, chirped pairs, warbles, trills.
    starts=np.linspace(2,56,[23,18,11,7][idx])+rng.uniform(-.8,.8,[23,18,11,7][idx])
    for k,start in enumerate(starts):
        family=k%4
        for note in range([3,2,4,6][family]):
            length=[.32,.14,.22,.075][family]*rng.uniform(.85,1.15)
            u=t-(start+note*[.39,.24,.30,.12][family])
            mask=(u>=0)&(u<length);v=u[mask]
            base=[2100,3400,2600,4100][family]+rng.uniform(-300,300)
            phase=2*np.pi*(base*v+[-1000,1800,300,-300][family]*v*v+10*np.sin(2*np.pi*9*v))
            env=np.sin(np.pi*v/length)**2
            a[mask]+=.055*env*(np.sin(phase)+.15*np.sin(2*phase))
    save('day-'+season,a)
    night=noise(rng,80,4500,.8)*.010
    if idx!=3:
        # Several asynchronous cricket chirrs, sparse in autumn.
        for freq,rate in [(3900,1.7),(4700,1.13),(5200,.83)]:
            gate=np.maximum(0,np.sin(2*np.pi*rate*t))**10
            pulses=np.maximum(0,np.sin(2*np.pi*31*t))**4
            night+=.012*(.5 if idx==2 else 1)*gate*pulses*np.sin(2*np.pi*freq*t)
    for start in [8,29,48]:
        for shift,length,gain in [(0,.38,.045),(.65,.75,.055),(1.8,.4,.033)]:
            u=t-start-shift;mask=(u>=0)&(u<length);v=u[mask]
            env=np.sin(np.pi*v/length)**2
            phase=2*np.pi*(360*v+10*v*v+1.0*np.sin(2*np.pi*4*v))
            night[mask]+=gain*env*(np.sin(phase)+.22*np.sin(2*phase)+.08*np.sin(3*phase))
    save('night-'+season,night)
rng=np.random.default_rng(333)
rain=noise(rng,180,8500,.18)*.047
for start in rng.uniform(0,59.9,450):
    u=t-start;mask=(u>=0)&(u<.025);v=u[mask]
    rain[mask]+=.026*np.exp(-v*160)*np.sin(2*np.pi*(1600+500*rng.random())*v)
save('rain',rain)
wind=noise(rng,40,1900,.85)*(.025+.028*(.5+.5*np.sin(2*np.pi*t/15))**2)
wind+=noise(rng,800,6000,.35)*(.004+.009*(.5+.5*np.sin(2*np.pi*t/12))**3)
save('wind',wind)
rumble=noise(rng,25,380,1.1);thunder=np.zeros(n)
for start in [12,39]:
    u=t-start;mask=(u>=0)&(u<13);v=u[mask]
    env=(1-np.exp(-v*2))*np.exp(-v*.32)
    thunder[mask]+=rumble[mask]*env*.09
save('thunder',thunder)

# Apply the current recorded owl and event-based thunder replacements.
import runpy
runpy.run_path(str(Path(__file__).resolve().with_name("refine_weather_audio.py")), run_name="__main__")

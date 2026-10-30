import numpy as np, math, random, sys, os
SC=float(os.environ.get('SC','1'))
OUT=os.environ.get('OUT','rose_rgb.npy')
from PIL import Image, ImageFilter, ImageDraw, ImageChops
S=2048; CX=CY=S/2
ys,xs=np.mgrid[0:S,0:S].astype(np.float32)
dx=xs-CX; dy=ys-CY
rho=np.sqrt(dx*dx+dy*dy)
phi=np.mod(np.arctan2(dx,-dy),2*np.pi)   # 0 = up, clockwise
LIGHT=math.radians(-40)                  # light from upper-left
def sstep(a,b,x):
    t=np.clip((x-a)/(b-a),0,1); return t*t*(3-2*t)
def ramp(u,stops):
    u=np.clip(u,0,1); out=np.zeros(u.shape+(3,),np.float32)
    for (p0,c0),(p1,c1) in zip(stops[:-1],stops[1:]):
        m=(u>=p0)&(u<=p1); t=((u-p0)/(p1-p0+1e-6))[...,None]
        out=np.where(m[...,None],np.array(c0)*(1-t)+np.array(c1)*t,out)
    return out
hexc=lambda h:[int(h[i:i+2],16) for i in (1,3,5)]
PETAL=[(0.0,hexc('#5E0F33')),(0.35,hexc('#8E1F4E')),(0.62,hexc('#CF467E')),(0.82,hexc('#F38DB1')),(0.93,hexc('#FFC2D6')),(1.0,hexc('#FFE9F1'))]
def gold(t):
    # metallic band: angle-driven so the rim catches light like real foil
    g=ramp(t,[(0,hexc('#8A5E1E')),(0.3,hexc('#D9A94F')),(0.5,hexc('#FFF0C8')),(0.7,hexc('#E6C277')),(1,hexc('#9E7129'))])
    return g

def silk(extra=0):
    return 1+0.035*np.sin(phi*420+7*np.sin(rho/37+extra))*np.sin(phi*97+rho/53)
layers=[]  # (rgb, alpha)

def guard(R,k,ph0,shade_shift=0.0):
    s=np.mod((phi-ph0)*k/(2*np.pi),1.0)
    bulge=np.sin(np.pi*s)**0.55
    Rb=R*(0.80+0.20*bulge-0.018*np.exp(-((s-0.5)/0.035)**2))
    u=rho/Rb
    a=np.clip((Rb-rho)/1.6,0,1)
    col=ramp(np.clip(u,0,1)**1.9+shade_shift,PETAL)
    # each petal is a shallow bowl: lit side vs shaded side
    mid=ph0+(np.floor((phi-ph0)*k/(2*np.pi))+0.5)*2*np.pi/k
    facing=np.cos(mid-LIGHT)
    side=(s-0.5)*2
    light=1+0.10*facing+0.10*side*np.sin(mid-LIGHT)*-1
    k=0.55*np.exp(-(np.minimum(s,1-s)/0.045)**2)*(1-0.6*u)
    col=col*(1-k[...,None])+np.array(hexc('#5E0F33'))*k[...,None]
    glob=1+0.13*np.cos(phi-LIGHT)*np.clip(u,0,1)
    col=col*(light*glob*silk(ph0))[...,None]
    # satin sheen near the lip
    sheen=np.exp(-((u-0.83)/0.07)**2)*np.clip(facing,0,1)*0.22
    col=col+(255-col)*sheen[...,None]
    # gold edge
    rim=np.clip(1-np.abs(Rb-rho-6)/5.6,0,1)
    gt=np.mod(phi*1.6/(2*np.pi)*k+0.3,1.0)
    col=col*(1-rim[...,None])+gold(gt)*rim[...,None]
    return col,a

def spiral(R0,R1,turns,ppt0,ppt1):
    TH=2*np.pi*turns
    def Rout(th):
        f=np.clip(th/TH,0,1); return R0+(R1-R0)*f**0.85
    def lip(th):
        f=np.clip(th/TH,0,1); ppt=ppt0+(ppt1-ppt0)*f
        psi=th*ppt/(2*np.pi); s=np.mod(psi,1.0)
        return Rout(th)*(1+0.07*np.sin(np.pi*s)**0.6-0.02),psi,s
    col=np.zeros((S,S,3),np.float32); A=np.zeros((S,S),np.float32)
    for n in range(int(turns)+1,-1,-1):
        th=phi+2*np.pi*n
        valid=(th<=TH).astype(np.float32)
        Ro,psi,s=lip(th)
        bulge=np.sin(np.pi*s)**0.6
        spacing=Rout(th+2*np.pi)-Rout(th)
        Wf=np.maximum(spacing*1.75,14)
        end=sstep(TH,TH-0.12*np.pi,th)   # ribbon ends in a clean folded petal edge
        Ri=Ro-Wf
        W=Wf
        u=(rho-Ri)/np.maximum(W,1e-3)
        a=np.clip((Ro-rho)/1.4,0,1)*np.clip((rho-Ri)/1.4,0,1)*valid*(W>2)*end
        s=np.where(th>TH-0.5*np.pi,np.minimum(s,1-sstep(TH-0.5*np.pi,TH,th)),s)
        c=ramp(0.12+0.88*np.clip(u,0,1)**1.25,PETAL)
        k=0.5*np.exp(-(np.minimum(s,1-s)/0.05)**2)*(1-0.7*u)
        c=c*(1-k[...,None])+np.array(hexc('#5E0F33'))*k[...,None]
        facing=np.cos(phi-LIGHT)
        c=c*((1+0.13*facing*u)*silk(n))[...,None]
        # shadow thrown by the next turn in (it stands taller)
        if n>0:
            Rp,_,_=lip(th-2*np.pi)
            dist=np.clip(rho-Rp,0,None)
            occ=1-0.55*np.exp(-dist/(10+0.04*Rp))
            c=c*occ[...,None]
        sheen=np.exp(-((u-0.80)/0.08)**2)*np.clip(facing,0,1)*0.28*bulge
        c=c+(255-c)*sheen[...,None]
        rim=np.clip(1-np.abs(Ro-rho-5.5)/4.8,0,1)*(W>2)
        c=c*(1-rim[...,None])+gold(np.mod(psi*0.5+0.2,1.0))*rim[...,None]
        col=col*(1-a[...,None])+c*a[...,None]
        A=A+a*(1-A)
    return [(col,A)]

def comp(base,c,a,shadow=True,sh_blur=16,sh_dy=12,sh_op=0.55):
    if shadow:
        am=Image.fromarray((a*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(sh_blur))
        am=np.roll(np.asarray(am).astype(np.float32)/255,sh_dy,axis=0)
        base=base*(1-sh_op*am)[...,None]+np.array([30,4,18])*(sh_op*am)[...,None]*0.0
    return base*(1-a[...,None])+c*a[...,None]

# ---------- background ----------
r=np.sqrt((xs-CX)**2+(ys-S*0.46)**2)/(S*0.74)
bg=ramp(r,[(0,hexc('#B53468')),(0.4,hexc('#7A1A48')),(0.78,hexc('#3D0A27')),(1,hexc('#200515'))])
uu=(xs*0.8+ys*0.6)/S
sheen=np.exp(-((uu-0.30-0.03*np.sin(xs/260))/0.06)**2)*0.10+np.exp(-((uu-1.12-0.03*np.sin(ys/300))/0.05)**2)*0.08
bg=bg+(np.array([255,205,220])-bg)*sheen[...,None]
aura=np.exp(-(rho/(S*0.36*SC))**2)*0.42
bg=bg+(np.array([255,150,185])-bg)*aura[...,None]
img=bg

g1=guard(S*0.395*SC,5,math.radians(8))
g2=guard(S*0.335*SC,5,math.radians(44),shade_shift=0.02)
img=comp(img,*g1,sh_blur=40,sh_dy=30,sh_op=0.55)
img=comp(img,*g2,sh_blur=18,sh_dy=12,sh_op=0.5)
for c,a in spiral(S*0.035*SC,S*0.255*SC,3.2,2.6,4.2):
    img=comp(img,c,a,sh_blur=10,sh_dy=8,sh_op=0.55)
np.save(OUT,img.astype(np.float32))
Image.fromarray(np.clip(img,0,255).astype(np.uint8)).resize((1024,1024),Image.LANCZOS).save('rose_raw.png')

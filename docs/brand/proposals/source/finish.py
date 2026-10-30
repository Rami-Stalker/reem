import numpy as np, math, random, os
SC=float(os.environ.get('SC','1')); RING=os.environ.get('RING')=='1'; IN=os.environ.get('IN','rose_rgb.npy'); OUTP=os.environ.get('OUTP','ohara_rose_1024.png')
from PIL import Image, ImageFilter, ImageDraw, ImageChops
random.seed(21)
S=2048
img=np.load(IN)
base=Image.fromarray(np.clip(img,0,255).astype(np.uint8))
ys,xs=np.mgrid[0:S,0:S].astype(np.float32)
def add_light(im,mask,col,op):
    m=np.asarray(mask).astype(np.float32)/255*op
    a=np.asarray(im).astype(np.float32)
    return Image.fromarray(np.clip(a+(np.array(col)-a)*m[...,None],0,255).astype(np.uint8))
def screen(im,mask,col,op):
    m=np.asarray(mask).astype(np.float32)/255*op
    a=np.asarray(im).astype(np.float32)/255; c=np.array(col)/255
    out=1-(1-a)*(1-c*m[...,None])
    return Image.fromarray(np.clip(out*255,0,255).astype(np.uint8))
# pearl at the heart
cx=cy=S/2; R=58*SC
yy,xx=ys-cy,xs-cx
d=np.sqrt(xx**2+yy**2)
sh=Image.fromarray((np.clip(1-(np.sqrt(xx**2+(yy-14)**2)-R)/18,0,1)*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))
a=np.asarray(base).astype(np.float32); sm=np.asarray(sh).astype(np.float32)/255*0.6
a=a*(1-sm[...,None])
nz=np.sqrt(np.clip(1-(d/R)**2,0,1))
nx,ny=xx/R,yy/R
L=np.array([-0.45,-0.6,0.66]); L=L/np.linalg.norm(L)
diff=np.clip(nx*L[0]+ny*L[1]+nz*L[2],0,1)
spec=np.clip(nx*L[0]+ny*L[1]+nz*L[2],0,1)**40
rimc=(1-nz)**2
pc=np.array([248,226,232.])*(0.55+0.5*diff)[...,None]+np.array([255,190,215.])*rimc[...,None]*0.35+255*spec[...,None]*0.9
# iridescent tint
pc=pc+np.stack([np.zeros_like(nx),12*np.sin(6*nx+3*ny),18*np.cos(5*ny-2*nx)],-1)*rimc[...,None]
pa=np.clip(R-d+0.8,0,1)
a=a*(1-pa[...,None])+pc*pa[...,None]
base=Image.fromarray(np.clip(a,0,255).astype(np.uint8))
# thin gold bezel around the pearl
bz=np.clip(1-np.abs(d-R-3)/3,0,1)
gold=np.array([233,196,120.])*(0.75+0.4*np.clip(-(nx*0.6+ny*0.8),-.5,1))[...,None]
a=np.asarray(base).astype(np.float32); a=a*(1-bz[...,None])+gold*bz[...,None]
base=Image.fromarray(np.clip(a,0,255).astype(np.uint8))

# dew diamonds resting on petals
def dew(im,x,y,r):
    a=np.asarray(im).astype(np.float32)
    dd=np.sqrt((xs-x)**2+(ys-y)**2)
    m=np.clip(r-dd+0.8,0,1)
    nxx=(xs-x)/r; nyy=(ys-y)/r
    inner=np.clip(1-dd/r,0,1)
    c=a*0.85+np.array([255,240,245.])*0.15
    c=c+255*np.clip(1-np.sqrt((nxx+0.35)**2+(nyy+0.4)**2)/0.35,0,1)[...,None]*0.9
    c=c+np.array([255,220,230.])*np.clip((nxx*0.5+nyy*0.6),0,1)[...,None]*0.35*inner[...,None]
    sh=np.clip(1-np.sqrt((xs-x-r*0.25)**2+(ys-y-r*0.45)**2)/(r*1.1),0,1)*(1-m)*0.35
    a=a*(1-sh[...,None])
    a=a*(1-m[...,None])+c*m[...,None]
    return Image.fromarray(np.clip(a,0,255).astype(np.uint8))
for (x,y,r) in [(0.30,0.36,15),(0.665,0.70,12),(0.73,0.33,10)]:
    base=dew(base,(0.5+(x-0.5)*SC)*S,(0.5+(y-0.5)*SC)*S,r*SC)

# drop of light: aura already in bg; add golden dust and twinkles
dust=Image.new('L',(S,S),0); dd=ImageDraw.Draw(dust)
for _ in range(110):
    x=random.uniform(0,S); y=random.uniform(0,S)
    if math.hypot(x-S/2,y-S/2)<S*0.41: continue
    rr=random.choice([2,2,3,3,4,5]); dd.ellipse([x-rr,y-rr,x+rr,y+rr],fill=random.randint(60,200))
dust=dust.filter(ImageFilter.GaussianBlur(1.3))
base=screen(base,dust,(255,226,180),1.0)
def twinkle(im,x,y,L,op=1.0):
    lay=Image.new('L',(S,S),0); ld=ImageDraw.Draw(lay)
    w=L*0.085
    ld.polygon([(x-L,y),(x,y-w),(x+L,y),(x,y+w)],fill=255)
    ld.polygon([(x,y-L),(x-w,y),(x,y+L),(x+w,y)],fill=255)
    l2=L*0.42; w2=w*0.8
    ld.polygon([(x-l2,y-l2),(x+w2,y-w2),(x+l2,y+l2),(x-w2,y+w2)],fill=110)
    ld.polygon([(x+l2,y-l2),(x+w2,y+w2),(x-l2,y+l2),(x-w2,y-w2)],fill=110)
    lay=lay.filter(ImageFilter.GaussianBlur(1.2))
    core=Image.new('L',(S,S),0); ImageDraw.Draw(core).ellipse([x-L*0.45,y-L*0.45,x+L*0.45,y+L*0.45],fill=170)
    core=core.filter(ImageFilter.GaussianBlur(L*0.25))
    m=ImageChops.lighter(lay,core).point(lambda v:int(v*op))
    return screen(im,m,(255,242,220),1.0)
for (x,y,L,o) in [(0.845,0.145,104,1),(0.13,0.20,56,0.9),(0.885,0.86,60,0.9),(0.14,0.84,40,0.85),(0.63,0.05,30,0.8),(0.055,0.52,26,0.7),(0.955,0.50,24,0.7),
                  (0.335,0.355,40,0.95),(0.69,0.695,32,0.9)]:
    if RING and math.hypot(x-0.5,y-0.5)>0.3: x,y=0.5+(x-0.5)*1.06,0.5+(y-0.5)*1.06
    if math.hypot(x-0.5,y-0.5)<0.3: x,y=0.5+(x-0.5)*SC,0.5+(y-0.5)*SC
    base=twinkle(base,x*S,y*S,L,o)

if RING:
    RR=S*0.44; th=10
    dd=np.sqrt((xs-S/2)**2+(ys-S/2)**2)
    ang=np.arctan2(ys-S/2,xs-S/2)
    # ring shadow
    a=np.asarray(base).astype(np.float32)
    shm=np.clip(1-np.abs(np.sqrt((xs-S/2)**2+(ys-S/2-14)**2)-RR)/(th+10),0,1)**2*0.45
    a=a*(1-shm[...,None])
    m=np.clip(th/2+0.8-np.abs(dd-RR),0,1)
    across=np.clip((dd-RR)/(th/2),-1,1)           # -1 inner edge .. 1 outer edge
    tube=np.sqrt(np.clip(1-across**2,0,1))
    sweep=0.5+0.5*np.cos(ang-math.radians(-130))
    t=np.clip(0.25+0.55*tube*sweep+0.25*np.cos(ang*3+1),0,1)
    stops=[(0,(110,72,24)),(0.35,(201,150,66)),(0.6,(240,206,130)),(0.85,(255,244,214)),(1,(255,255,245))]
    gc=np.zeros(t.shape+(3,),np.float32)
    for (p0,c0),(p1,c1) in zip(stops[:-1],stops[1:]):
        mm=(t>=p0)&(t<=p1); w=((t-p0)/(p1-p0))[...,None]
        gc=np.where(mm[...,None],np.array(c0)*(1-w)+np.array(c1)*w,gc)
    a=a*(1-m[...,None])+gc*m[...,None]
    base=Image.fromarray(np.clip(a,0,255).astype(np.uint8))
    # brilliant-cut diamond set on the ring
    dax=S/2+RR*math.cos(math.radians(-48)); day=S/2+RR*math.sin(math.radians(-48))
    rD=30
    lay=Image.new('RGBA',(S,S),(0,0,0,0)); ld=ImageDraw.Draw(lay)
    ld.ellipse([dax-rD-7,day-rD-7,dax+rD+7,day+rD+7],fill=(214,170,90,255))
    pts=[(dax+rD*math.cos(math.radians(k*45+22.5)),day+rD*math.sin(math.radians(k*45+22.5))) for k in range(8)]
    for k in range(8):
        p1=pts[k]; p2=pts[(k+1)%8]
        shade=200+int(55*math.cos(math.radians(k*45-120)))
        ld.polygon([(dax,day),p1,p2],fill=(shade,shade-8,shade-2,255))
    tbl=[(dax+rD*0.5*math.cos(math.radians(k*45+22.5)),day+rD*0.5*math.sin(math.radians(k*45+22.5))) for k in range(8)]
    ld.polygon(tbl,fill=(250,246,252,255))
    for k in range(8): ld.line([tbl[k],pts[k]],fill=(180,170,190,255),width=2)
    base=base.convert('RGBA'); base.alpha_composite(lay); base=base.convert('RGB')
    base=twinkle(base,dax,day,120,1.0)
# soft vignette
r=np.sqrt((xs-S/2)**2+(ys-S/2)**2)/(S*0.72)
v=np.clip(1-0.32*np.clip((r-0.58)/0.42,0,1),0,1)
a=np.asarray(base).astype(np.float32)*v[...,None]
out=Image.fromarray(np.clip(a,0,255).astype(np.uint8)).resize((1024,1024),Image.LANCZOS)
out.save('ohara_rose_1024.png')

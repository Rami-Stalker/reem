# Ohara Rose icon — source

The rose is painted procedurally (no AI image, no third-party artwork):

```
python3 rose.py                      # SC=0.86 OUT=B.npy for the ring version
python3 finish.py                    # SC=0.86 RING=1 IN=B.npy adds the gold "O" ring + diamond
```

`rose.py` shades every pixel of a satin ribbon rose: two rings of guard petals and a
spiral heart, each with gilded rims, silk striations and self-shadowing.
`finish.py` adds the pearl, dew drops, sparkles, the optional ring and the vignette,
and writes `ohara_rose_1024.png`. Needs numpy and Pillow.

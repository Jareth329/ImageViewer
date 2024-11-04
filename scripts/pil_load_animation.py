import sys, io, base64, clr
clr.AddReference('ImageViewer')
from ImageViewer.Python import PythonManager
from PIL import Image, ImageFile, GifImagePlugin
ImageFile.LOAD_TRUNCATED_IMAGES = True
GifImagePlugin.LOADING_STRATEGY = GifImagePlugin.LoadingStrategy.RGB_ALWAYS

<<<<<<< Updated upstream
=======
def get_main_color(pil_img, palette_size=16):
    # Resize image to speed up processing
    img = pil_img.copy()
    img.thumbnail((100, 100))

    # Reduce colors (uses k-means internally)
    paletted = img.convert('P', palette=Image.ADAPTIVE, colors=palette_size)

    # Find the color that occurs most often
    palette = paletted.getpalette()
    color_counts = sorted(paletted.getcolors(), reverse=True)
    palette_index = color_counts[0][1]
    dominant_color = palette[palette_index*3:palette_index*3+3]

    return dominant_color

>>>>>>> Stashed changes
def is_animation(path):
    img = Image.open(path)
    frame_count = 1 if not hasattr(img, 'n_frames') else img.n_frames
    if frame_count > 1: 
<<<<<<< Updated upstream
        return True
    return False
=======
        return f'T?{get_main_color(img)}'
    return f'F?{get_main_color(img)}'
>>>>>>> Stashed changes

def has_transparency(img):
    if img.info.get("transparency", None) is not None:
        return True
    if img.mode == "P":
        transparent = img.info.get("transparency", -1)
        for _, index in img.getcolors():
            if index == transparent:
                return True
    elif img.mode == "RGBA":
        extrema = img.getextrema()
        if extrema[3][0] < 255:
            return True
    return False

def get_frames(path):
    img = Image.open(path)
    frame_count = img.n_frames
    
    csharp = PythonManager()
    csharp.SendImageInfo(f'{frame_count}?{path}')
    
    type = 'jpeg'
    if has_transparency(img) or img.mode == 'RGBA' or img.mode == 'RAW':
        type = 'webp'
    
    for i in range(0, frame_count):
        if csharp.StopLoading(path): break
        stream = io.BytesIO()
        img.seek(i)
        if type == 'jpeg': img.save(stream, 'jpeg', disposal=1, quality=95)
        else: img.save(stream, 'webp', blend=1, compress_level=0, quality=95)
        
        b64_img = str(base64.b64encode(stream.getvalue()))
        b64_img = b64_img.replace('\'', '')
        b64_img = b64_img[1:len(b64_img)]
        duration = str(img.info['duration'])
        b64_img = f'{type}?{path}?{duration}?{b64_img}'
        csharp.SendAnimationFrame(b64_img)

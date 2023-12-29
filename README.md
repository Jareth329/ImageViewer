# ImageViewer
 
### Controls
L-mouse : pan

M-mouse : rotate

R-mouse : reset

Scroll : zoom

V-key : toggle image vertical flip

H-key : toggle image horizontal flip

F-key : toggle image filter (nearest / linear)

L-arrowkey : change to previous image in current folder

R-arrowkey : change to next image in current folder

> arrowkeys will both loop back to other side when end is reached

TAB : toggle ui visibility (currently just counter)

ESC or F8 : exit program

F9 : toggle titlebar visibility

F10 : toggle maximized

F11 : toggle fullscreen

### Notes
- rotation and zoom are both relevant to the center of the window, not the center of the image
- drag and drop an image into program from file system to view it (jpeg/png/bmp/dds/ktx/exr/hdr/tga/svg/webp should have some level of support currently)
- > can also set the program as the 'Open With' program for supported extensions
- > will add the ability to set associations automatically when I switch to csharp (along with supporting more+animated formats)
- will add dedicated buttons for various hotkeys later

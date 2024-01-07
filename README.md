# ImageViewer
 
### Controls
- Left Mouse : pan
- Middle Mouse : fast zoom
- Right Mouse : rotate
- Scroll : change images / zoom (depending on setting)
---
- Tab : toggle ui visibility (currently just counter)
- B-key : toggles background transparency
- V-key : toggle image vertical flip
- H-key : toggle image horizontal flip
- F-key : toggle image filter (nearest / linear)
---
- Left-arrowkey : change to previous image in current folder
- Right-arrowkey : change to next image in current folder
- Up-arrowkey : change to nth previous image (10 by default)
- Down-arrowkey : change to nth next image (10 by default)
  - arrowkeys will both loop back to other side when end is reached
---
- F5 or R-key : reset camera/flip state
- F8 or ESC : exit program
- F9 : toggle titlebar visibility
- F10 : toggle maximized
- F11 : toggle fullscreen

### Notes
- rotation and zoom are both relevant to the center of the window, not the center of the image
  - scroll-wheel zoom currently defaults to zooming towards/from mouse cursor instead of screen center

- drag and drop an image into program from file system to view it (jpeg/png/bmp/dds/ktx/exr/hdr/tga/svg/webp should have some level of support currently)
  - can also set the program as the 'Open With' program for supported extensions
  - will add the ability to set associations automatically when I switch to csharp (along with supporting more+animated formats)

- will add dedicated buttons for various hotkeys later

### Issues
- it is possible for window to become very small in windowed mode
  - has happened twice now; no idea how to trigger
  - can be fixed by manually resizing; likely fixed by changing displayed image as well

- main problem currently is that godot4 projects have a baseline memory overhead of ~140-180MB; which is really way too much for a program expected
  to run multiple instances
  - considering trying to change approach to use multiple windows with only 1 actual instance; main problem with that is how to handle opening multiple
    images at once in file explorer

- if zoomed in to an image (not center) and panning and spin mouse cursor in circles; camera will move towards center of image
  - not a problem in normal use cases, so small issue
  - likely an inherent consequence of the code I made for zoom_to_point

- no error displayed in program when image fails to load
  - most issues will be fixed by the move to csharp
  - for the actually broken images; I will likely remove their path from array and update index/displayed image accordingly

# ImageViewer
 
### Controls
- Left Mouse : pan
- Middle Mouse : fast zoom
- Right Mouse : rotate
- Scroll : change image
- CTRL + Scroll : zoom to cursor
- SHIFT + Scroll : vertical pan
---
- Tab-key : toggle ui visibility (currently just counter)
- B-key : toggles background transparency (currently broken)
- V-key : toggle image vertical flip
- H-key : toggle image horizontal flip
- F-key : toggle image filter (nearest / linear)
- R-key : reset camera/flip state
- X-key : toggle always use full space
  - currently, on : image resizes from the window origin up to ~5% of the screen away from the edge
  - off : image resizes from window origin up to a maximum of 75% of the screen dimensions
- Z-key : toggle horizontal fit mode (currently not properly implemented)
---
- Left-arrowkey : change to previous image in current folder
- Right-arrowkey : change to next image in current folder
- Up-arrowkey : change to nth previous image (10 by default)
- Down-arrowkey : change to nth next image (10 by default)
  - arrowkeys will both loop back to other side when end is reached
---
- F1 : maximize
- F2 : toggle titlebar
- F3 : toggle image border
- F4/F11 : fullscreen
- F5 : refreshes the list of paths (if images added/removed/renamed)
- ESC : exit program

### Notes
- rotation and zoom are both relevant to the center of the window, not the center of the image
  - ctrl + scroll-wheel zoom currently defaults to zooming towards/from mouse cursor instead of screen center

- drag and drop an image into program from file system to view it (jpeg/jfif/png/bmp/dds/ktx/exr/hdr/tga/svg/webp should have some level of support currently)
  - can also set the program as the 'Open With' program for supported extensions
  - will add the ability to set associations automatically when I switch to csharp (along with supporting more+animated formats)

- will add dedicated buttons for various hotkeys later

### Issues
- maximized mode (with F10 key) currently does not work, need to look into

- if zoomed in to an image (not center) and panning and spin mouse cursor in circles; camera will move towards center of image
  - this is currently fixed, most likely it is an issued with the DAMPED mode for panning

- no error displayed in program when image fails to load
  - most issues will be fixed by the move to csharp
  - for the actually broken images; I will likely remove their path from array and update index/displayed image accordingly
  - most common issues are resolved for now

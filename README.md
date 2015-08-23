##### About

This is a very simple volume renderer. It comes compiled for Linux, OSX and Irix operating systems.

Most volume rendering tools are one of three types: 2D texture slicing, 3D texture slicing and ray casting. This software can be compiled as either a 3D or 2D texture slicer. By default it uses a 2D scheme.
 - 2D Texture slicing supports ancient hardware. However, it can exhibit artifacts - in particular when the view axis is about 45-degrees from the slice axis. It requires a lot of texture memory (a basic system requires 12 bytes per voxel: RGBA for each slice axis). An example of an ideal computer for this scheme is the SGI O2: it performs very poorly with 3D textures yet all of the the system memory can be used for textures.
 - 3D Texture slicing is simple to implement. Most implementations require 4 bytes per voxel (a RGBA mapping).
 - Raycasting requires a modern video card that supports programmable shaders. It is easy to implement features like stochastic jitter (to reduce wood-grain artifacts), color palettes (so an image can be stored with just 1 byte per voxel) and surface shading. 

##### Usage

Run the appropriate executable from the command line. For Macintosh OSX run 'vx_osx', for Linux run 'vx_linux' and for SGI Irix you run 'vx_irix'. By default, the software will load the image 'vx.nii.gz' - to open a specific file just specify the file name when you launch the program, e.g. 'vx_irix vx256.nii.gz'.

Once the program is running you can use the mouse to rotate the image. Here are a few keyboard commands:
 - arrow keys     : rotate object
 - b key          : background color change
 - c key          : clip plane on/off
 - q key          : quality better/worse
 - 1/2 keys       : change brightness
 - 3/4 keys       : change contrast
 - 5/6 keys       : change color table
 - esc key        : quit

##### Compiling

 - For OSX  
 	gcc vx.c -o vx -framework OpenGL -framework GLUT -Wno-deprecated-declarations
 - For Linux (or gcc on SGI)
	gcc vx.c -o vx -lglut -lGLU -lGL -lXext -lX11 -lm
 - For SGI (using SGI's MIPSpro)
	cc vx.c -o vx /usr/lib/libglut.a -lGLU -lGL -lXmu -lXext -lX11 -lm
 - Or simply 
	cc vx.c -o vx -lglut -lGLU -lGL -lXmu -lXext -lX11 -lm
 - To compile for 3D textures simply add "-Dtexture3D", for example (OSX)
 	gcc vx.c -o vx3d -framework OpenGL -framework GLUT -Wno-deprecated-declarations -Dtexture3D

##### Limitations

 - This software can only view NIfTI images saved with the .nii or .nii.gz extension. You can convert DICOM images to NIfTI using dcm2nii.
 - This software can only reads 8-bit images.
 - This software ignores the spatial transform stored in the NIfTI header. The image dimensions may not correspond to what you expect.
 - Be aware that some graphics cards (pre 2006) have problems with images with dimensionsthat are not powers of two. For example, if you have an image with 109 slices you will have to use another software to pad the image to have 128 slices.
 
 
##### Inspiration

This code leverages these open source projects

 - [VolumeRendering: Divine Augustine (view-aligned 3D, 32 bytes per voxel)](http://www.codeproject.com/Articles/352270/Getting-started-with-Volume-Rendering)
 - [Vox: Yusuf Attarwala (slice-aligned 3D, 16 bytes per voxel)](ftp://ftp.sgi.com/sgi/demos/)
 - [Volume from the Advanced97 glut demos (view-aligned 3D, 32 bytes per voxel)](https://www.cosc.brocku.ca/Offerings/3P98/course/OpenGL/glut-3.7/progs/advanced97/volume.c)
 - [MRIcroGL: Chris Rorden (raycasting, 64 bytes per voxel)](http://www.mccauslandcenter.sc.edu/mricrogl/)
 - [NIFTI header](http://nifti.nimh.nih.gov/pub/dist/src/niftilib/nifti1.h)
 - [Leandro R Barbagallo's WebGL raycaster](https://github.com/lebarba/WebGLVolumeRendering)

##### Versions

123-August-2015
 - Initial release

##### Sample images

The first three panels below show this software displaying the sample images included with the software. The right-most image shows the same image as the the third but created using a ray caster (MRIcroGL).


![alt tag](https://raw.githubusercontent.com/neurolabusc/vx/master/vx.jpg)
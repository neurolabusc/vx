##### About

This is a very simple volume renderer. It comes compiled for Linux, OSX and Irix operating systems.

Most volume rendering tools are one of three types: 2D texture slicing, 3D texture slicing and ray casting. This software allows you to compare each of these methods with the same image (using the 'm' key to switch between methods).
 - 2D Texture slicing supports ancient hardware. However, it can exhibit artifacts - in particular when the view axis is about 45-degrees from the slice axis. It requires a lot of texture memory (a basic system requires 12 bytes per voxel: RGBA for each slice axis). An example of an ideal computer for this scheme is the SGI O2: it performs very poorly with 3D textures yet all of the the system memory can be used for textures.
 - 3D Texture slicing is simple to implement. Most implementations require 4 bytes per voxel (a RGBA mapping).
 - Ray Casting requires a modern video card that supports programmable shaders. It is easy to implement features like stochastic jitter (to reduce wood-grain artifacts), color palettes (so an image can be stored with just 1 byte per voxel) and surface shading (though this demo does not apply surface shading, see MRIcroGL). 

##### Usage

Run the appropriate executable from the command line (these are in the 'dist' folder). For Macintosh OSX run 'vx_osx', for Linux run 'vx_linux' and for SGI Irix you run 'vx_irix'. By default, the software will load the image 'vx.nii.gz' - to open a specific file just specify the file name when you launch the program, e.g. 'vx_irix vx256.nii.gz'.

Once the program is running you can use the mouse to rotate the image. Here are a few keyboard commands:
 - arrow keys     : rotate object
 - b key          : background color change
 - c key          : clip plane on/off **Ignored by RayCast**
 - m key          : method (2D/3D/RayCast) **RayCast not available for IRIX**
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

##### Limitations

 - This software can only view NIfTI images saved with the .nii or .nii.gz extension. You can convert DICOM images to NIfTI using dcm2nii.
 - This software can only reads 8-bit images.
 - This software ignores the spatial transform stored in the NIfTI header. The image dimensions may not correspond to what you expect.
 - Be aware that some graphics cards (pre 2006) have problems with images with dimensionsthat are not powers of two. For example, if you have an image with 109 slices you will have to use another software to pad the image to have 128 slices.
 
##### vxgui

The 'dist' folder also includes a graphical user interface version of this software for Windows (vxgui_win), Macintosh (vxgui_osx) and 64-bit Linux (vxgui_lx). This version allows you to choose between ray casting and 3D view-aligned textures. The ray casting also allows other features such as using gradients to emphasize the edges. The source code for this project is provided in the srcgui folder and requires the free [Lazarus integrated development environment](http://www.lazarus-ide.org).
 
##### Inspiration

This code leverages these open source projects

 - [VolumeRendering: Divine Augustine (view-aligned 3D, 32 bytes per voxel)](http://www.codeproject.com/Articles/352270/Getting-started-with-Volume-Rendering)
 - [Vox: Yusuf Attarwala (slice-aligned 3D, 16 bytes per voxel)](https://www.cosc.brocku.ca/Offerings/3P98/course/OpenGL/glut-3.7/progs/advanced/vox.c)
 - [Volume from the Advanced97 glut demos (view-aligned 3D, 32 bytes per voxel)](https://www.cosc.brocku.ca/Offerings/3P98/course/OpenGL/glut-3.7/progs/advanced97/volume.c)
 - [MRIcroGL: Chris Rorden (ray casting, 64 bytes per voxel)](http://www.mccauslandcenter.sc.edu/mricrogl/)
 - [NIFTI header](http://nifti.nimh.nih.gov/pub/dist/src/niftilib/nifti1.h)
 - [Leandro R Barbagallo's WebGL ray casting](https://github.com/lebarba/WebGLVolumeRendering)

##### Versions

 - 23-August-2015: Initial release
 - 30-August-2015: Added ray casting

##### Sample images

In the columns below the images show the three methods supported by this software: 2D texture slicing (object aligned), 3D texture slicing (viewer aligned) and ray casting. You can switch between methods using the 'm' key. The top row shows high quality rendering while the lower panel shows the faster low-quality performance. You can change the quality by pressing the 'q' key.

![alt tag](https://raw.githubusercontent.com/neurolabusc/vx/master/vx_methods.jpg)

The first three panels below show this software displaying the sample images included with the software. The right-most image shows the same image as the the third but created using a ray caster that applies surface lighting (MRIcroGL).


![alt tag](https://raw.githubusercontent.com/neurolabusc/vx/master/vx.jpg)
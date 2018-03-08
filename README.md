# TrackRoots
This is a `Julia` script for analysing light intensities as a function of time and space in time-lapse image stacks of seedling roots.

| Windows | macOS | Coverage |
| --- | --- | --- |
| [![Build status](https://ci.appveyor.com/api/projects/status/ea1xn7716t4xse0i/branch/master?svg=true)](https://ci.appveyor.com/project/yakir12/trackroots-jl/branch/master) | [![Build Status](https://travis-ci.org/yakir12/TrackRoots.jl.svg?branch=master)](https://travis-ci.org/yakir12/TrackRoots.jl) | [![Coverage Status](https://coveralls.io/repos/github/yakir12/TrackRoots.jl/badge.svg?branch=master)](https://coveralls.io/github/yakir12/TrackRoots.jl?branch=master) |

## How to install
1. If you haven't already, install the current release of [Julia](https://julialang.org/downloads/) -> you should be able to launch it (some icon on the Desktop or some such).
2. Start Julia -> a Julia-terminal popped up.
3. Copy: 
   ```julia
   Pkg.clone("https://github.com/yakir12/TrackRoots.jl")
   Pkg.build("TrackRoots")
   ```
   and paste it in the newly opened Julia-terminal, press Enter -> this may take a long time.
4. (*not necessary*) To test the package, copy: 
   ```julia
   Pkg.test("TrackRoots")
   ```
   and paste it in the Julia-terminal. Press enter to check if all the tests pass -> this may also take a long time (all tests should pass).
5. You can close the Julia-terminal after it's done running.

## Quick start
1. Start Julia -> a Julia-terminal popped up.
2. Copy and paste this in the newly opened Julia-terminal: 
   ```julia
   using TrackRoots
   main()
   ``` 
   You will be asked to navigate to the `.nd` file you want to analyse and select the root tips for each of the stages. 
   
**Note:** The first time this is executed will be significantly slower than all subsequent runs. While this is annoying, one simple remedy is to simply keep this terminal open and rerun `main()` every time you need to analyse another dataset.

Click to see a tutorial video on how to use the program:

<a href="https://vimeo.com/258615822" target="_blank"><img src="https://raw.githubusercontent.com/yakir12/TrackRoots.jl/master/docs/front.png" 
alt="TrackRoots tutorial video" width="400" height="400" border="10" /></a>


## Detailed instructions
1. The analysis is performed per `.nd` file. These files contain all the information needed to process the dark and bright 16-bit TIF images for all stages. 
2. After choosing the `.nd` file, you'll be presented with a composite image of the first stage. In order to help with identifying the correct root tip, this image shows you a composite of the first and last frames of the time-lapse. To select a root tip `Shift-click` on the tip of a root you want to include in your analysis. A red dot will appear where you've clicked. To unselect press `Shift-Crtl-click` in the vicinity of the spot/s you want to remove. The closest spots will disappear.

   To facilitate identification use the zoom: `Ctrl-click` and drag somewhere inside the image. You'll see the typical rubberband selection, and once you let go the image display will zoom in on the selected region. If you click on the image without holding down `Ctrl`, you can drag the image to look at nearby regions. `Ctrl-double-click` on the image to restore the full region. If you have a wheel mouse, zoom in again and scroll the wheel, which should cause the image to pan vertically. If you scroll while holding down `Shift`, it pans horizontally; hold down `Ctrl` and you affect the zoom setting.

   To help you identify what constitutes a root-tip, watch [this video](https://vimeo.com/258952278) show-casing the process for 21 root-tips.
3. Close the window when you're done selecting root tips. This process will repeat for all the stages in that dataset. To skip a stage simply close the window without selecting any root tips.
4. Once you've finished selecting root tips in all of the stages, the program will automatically calibrate all the images, track all the roots, and save the results into `csv` files and `gif` files (notifying you of its progress in each step). 
5. You can close the Julia-terminal after it's done running (or keep it open to save time in the next run).

## Results
Each root in each stage will result in 4 files: 
1. `coordinates.csv`: a comma separated file with the `[x, y]` coordinates of the root (in mm).
2. `intensities.csv`: a comma separated file with the lengths in mm, times in hours, and intensities. The first column is the root lengths (i.e. the distance along the root between the starting location of the tip and its current location), the second column is the intensities at time 0 hours, the third column is the intensities at the next period, etc. 
3. `intensities.png`: a heat-map plot of the intensities as a function of time in hours (x-axis) and root length in mm (y-axis).
4. `root.gif`: showing the tracked root as a time-lapse gif of the track in red.

These files are saved in the same directory the `.nd` file is in and organized into one folder per stage, and one folder per root per stage.

### 1. Video
The video file shows:
![video frame](./docs/video.png)

1. An image of the progression of the root and its track (`x` and `y` axis are in mm).
2. A heat-map describing the intensity of the root tip as a function of time in hours and root length in mm (i.e. the distance along the root between the starting location of the tip and its current location).
3. A plot of the intensity as a function of root length in mm.
4. A plot of the intensity as a function of time in hours.

as the video plays, these change as a function of time.

## How to update
To update your local version of `TrackRoots`, copy-paste this in a Julia-terminal: 
```julia
Pkg.update()
``` 

**Note:** After an update, the next time you run `TrackRoots` (almost any Julia script really) will be slower than usual. However, all subsequent runs will be fast.

## How does it all work?
The structure of the `.nd` file is translated into a type system for efficient and secure handling of the data. This procedure should be able to handle any combination of stages/wavelengths. The root-tip points are selected via a `Gtk` library. The spatial calibration works by automatically detecting the grid-lines in the bright images using a Hough transform. The limitation of this process is that at least two clear unobstructed grid-lines should be visible in one of the bright images. The temporal calibration works by extracting the original modification/creation times of the image files using `exiftools`. The advantage of this method is that you can safely run it on copied images (i.e. not the original files) and it will still work. Tracking the roots works via a Kalman filter which auto corrects its estimates from image-feedback. This leads to a robust and accurate root trajectory. Finally, saving the results is done by creating an informative gif and data files.

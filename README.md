# TrackRoots
This is a `Julia` script for analysing light intensities as a function of time and space in time-lapse image stacks of seedling roots.

[![Build Status](https://travis-ci.org/yakir12/TrackRoots.jl.svg?branch=master)](https://travis-ci.org/yakir12/TrackRoots.jl) [![Build status](https://ci.appveyor.com/api/projects/status/ea1xn7716t4xse0i/branch/master?svg=true)](https://ci.appveyor.com/project/yakir12/trackroots-jl/branch/master)

[![Coverage Status](https://coveralls.io/repos/yakir12/TrackRoots.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/yakir12/TrackRoots.jl?branch=master) [![codecov.io](http://codecov.io/github/yakir12/TrackRoots.jl/coverage.svg?branch=master)](http://codecov.io/github/yakir12/TrackRoots.jl?branch=master)

## How to install
1. If you haven't already, install the current release of [Julia](https://julialang.org/downloads/) -> you should be able to launch it (some icon on the Desktop or some such).
2. Start Julia -> a Julia-terminal popped up.
3. Copy: `Pkg.clone("git://github.com/yakir12/TrackRoots.jl.git"); Pkg.build("TrackRoots")` and paste it in the newly opened Julia-terminal, press Enter -> this may take a long time.
4. (*not necessary*) To test the package, copy: `Pkg.test("TrackRoots")` and paste it in the Julia-terminal. Press enter to check if all the tests pass -> this may also take a long time.
5. You can close the Julia-terminal after it's done running.

## Quick start

1. Start Julia -> a Julia-terminal popped up.
2. Copy and paste this in the newly opened Julia-terminal: 
   ```julia
   using TrackRoots
   main()
   ``` 
   You will be asked to navigate to the `.nd` file you want to analyse and select the root tips for each of the stages. **Note:** The first time this is executed will be significantly slower than all subsequent runs. While this is annoying, one simple remedy is to simply keep this terminal open and rerun `main()` every time you need to analyse another dataset.

## Detailed instructions

1. The analysis is performed per `.nd` file. These files contain all the information needed to process the dark and bright 16 bit tif images for all stages. 
2. After choosing the `.nd` file, you'll be presented with a composite image of the first stage. In order to help with identifying the correct root tip, this image shows you a composite of the first and last frames of the time-lapse. To select a root tip press `Shift-click`. A red dot will appear where you've clicked. To unselect press `Shift-Crtl-click` in the vicinity of the spot/s you want to remove.  
   Additionally, `Ctrl-click` and drag somewhere inside the image. You'll see the typical rubberband selection, and once you let go the image display will zoom in on the selected region. If you click on the image without holding down Ctrl, you can drag the image to look at nearby regions. `Ctrl-double-click` on the image to restore the full region.
   If you have a wheel mouse, zoom in again and scroll the wheel, which should cause the image to pan vertically. If you scroll while holding down `Shift`, it pans horizontally; hold down `Ctrl` and you affect the zoom setting.
3. Close the window when you're done selecting root tips. This process will repeat for all the stages in that dataset. To skip a stage simply close the window without selecting any root tips.
4. Once you've finished selecting root tips in all of the stages, the program will automatically calibrate all the images, track all the roots, and save the results into `hdf5` files and `mp4` files (notifying you of its progress in each step). 
5. You can close the Julia-terminal after it's done running (or keep it open to save time in the next run).


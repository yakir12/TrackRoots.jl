# TrackRoots
This is a `Julia` script for analysing light intensities as a function of time and space in time-lapse image stacks of *Arabidopsis* seedling roots.

[![Build Status](https://travis-ci.org/yakir12/TrackRoots.jl.svg?branch=master)](https://travis-ci.org/yakir12/TrackRoots.jl) [![Build status](https://ci.appveyor.com/api/projects/status/ea1xn7716t4xse0i/branch/master?svg=true)](https://ci.appveyor.com/project/yakir12/trackroots-jl/branch/master)

[![Coverage Status](https://coveralls.io/repos/yakir12/TrackRoots.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/yakir12/TrackRoots.jl?branch=master) [![codecov.io](http://codecov.io/github/yakir12/TrackRoots.jl/coverage.svg?branch=master)](http://codecov.io/github/yakir12/TrackRoots.jl?branch=master)

## How to install
1. If you haven't already, install the current release of [Julia](https://julialang.org/downloads/) -> you should be able to launch it (some icon on the Desktop or some such).
2. Start Julia -> a Julia-terminal popped up.
3. Copy: `Pkg.clone("git://github.com/yakir12/TrackRoots.jl.git"); Pkg.build("TrackRoots")` and paste it in the newly opened Julia-terminal, press Enter -> this may take a long time.
4. (*not necessary*) To test the package, copy: `Pkg.test("TrackRoots")` and paste it in the Julia-terminal. Press enter to check if all the tests pass -> this may also take a long time.
5. You can close the Julia-terminal after it's done running.

## How to use

1. Start Julia -> a Julia-terminal popped up.
2. Copy and paste this in the newly opened Julia-terminal: 
   ```julia
   using TrackRoots
   main(<ndfile>)
   ``` 
   where `<ndfile>` is the path to the `.nd` file that you want to analyse. If you prefer, you can omit that argument, `main()`, in which case you will be asked to navigate to the desired `.nd` file. **Note:** The first time this is executed will be significantly slower than all subsequent runs. While this is annoying, one simple remedy is to simply keep this terminal open and rerun `main()` every time you need to analyse another dataset.
3. After pressing Enter, you'll be presented with an image of the first stage. To select a root tip, hold the Shift button and left-click with your mouse. A red dot will appear where you've clicked. To unselect hold the Shift-Crtl buttons while left clicking in the vicinity of the spot/s you want to remove. Close the window when you're done. This process will repeat for all the stages in that dataset. To skip a stage simply close the window without selecting any root tips.
4. Once you've finished selecting root tips in all of the stages, the program will automatically calibrate all the images, track all the roots, save the results into `hdf5` files and `gif` files (notifying you of its progress in each step). 
5. You can close the Julia-terminal after it's done running (or keep it open to save time in the next run).


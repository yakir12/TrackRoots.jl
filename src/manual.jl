################################################################################
# Fill this with the desire values:
nd_file = "/home/yakir/.julia/datadeps/all/2/204.nd"
stage_number = 1
root_tips = [
             (649, 993), 
             (618, 919),
             (673, 821)
            ]
################################################################################


using TrackRoots
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
md = nd2metadata(nd_file)
roots = mytrack(md.stages[stage_number], CartesianIndex.(root_tips))



using ImageAxes
img = AxisArray(img,
                Axis{:x}(1mm:1mm:1024mm),
                Axis{:y}(1mm:1mm:1024mm))

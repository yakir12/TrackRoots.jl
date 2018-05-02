include(joinpath(Pkg.dir("TrackRoots"), "src", "utils.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "stages.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "startPoints.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "calibrates.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "saves.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "nodes.jl"))
#=function main(stages::Vector{Stage}, startpoints::Vector{Vector{Mark}}, Δx::Float64, output::IO)
    calibstages = stages2calib(stages, Δx)
    output == STDERR && info("Calibrated the data. Tracking the roots…")
    tracks = trackroot.(calibstages, startpoints)
    output == STDERR && info("Tracked the roots. Saving the results…")
    saveit(calibstages, tracks, output)
    output == STDERR && info("Done!")
end=#
rm("/home/yakir/.julia/datadeps/all/9/pos1,3-dr5_pos2,4-cle44-luc-1-5/stage 2/", force=true, recursive=true)
mkdir("/home/yakir/.julia/datadeps/all/9/pos1,3-dr5_pos2,4-cle44-luc-1-5/stage 2")
ndfile = "/home/yakir/.julia/datadeps/all/9/pos1,3-dr5_pos2,4-cle44-luc-1-5.nd"
stages = nd2stages(ndfile)
Δx = 0.04993757802746567
startpoints = [StaticArrays.SArray{Tuple{2},Float64,1,2}[]                
,StaticArrays.SArray{Tuple{2},Float64,1,2}[[511.26, 550.57]]
,StaticArrays.SArray{Tuple{2},Float64,1,2}[]                
,StaticArrays.SArray{Tuple{2},Float64,1,2}[]]
# main(stages, startpoints, Float64(Δx), STDERR)
calibstages = stages2calib(stages, Δx)
tracks = trackroot.(calibstages, startpoints)
saveit(calibstages, tracks, STDERR)

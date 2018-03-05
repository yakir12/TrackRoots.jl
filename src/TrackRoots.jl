__precompile__()
module TrackRoots

using Gtk

include(joinpath(Pkg.dir("TrackRoots"), "src", "utils.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "Stages.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "StartPoints.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "Calibrates.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "Tracks.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "Saves.jl"))

function main(ndfile::String = open_dialog("Pick an `.nd` file", GtkNullContainer(), ("*.nd",)))
    stages = nd2stages(ndfile)
    startpoints = get_startpoints.(stages)
    calibstages = stages2calib(stages)
    tracks = trackroot.(calibstages, startpoints)
    saveit(calibstages, tracks)
end

end # module

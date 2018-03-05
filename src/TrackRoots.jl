__precompile__()
module TrackRoots

export main

using Gtk

include(joinpath(Pkg.dir("TrackRoots"), "src", "utils.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "stages.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "startPoints.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "calibrates.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "saves.jl"))

function main(ndfile::String = open_dialog("Pick an `.nd` file", GtkNullContainer(), ("*.nd",)))
    stages = nd2stages(ndfile)
    startpoints = get_startpoints.(stages)
    calibstages = stages2calib(stages)
    tracks = trackroot.(calibstages, startpoints)
    saveit(calibstages, tracks)
end

end # module

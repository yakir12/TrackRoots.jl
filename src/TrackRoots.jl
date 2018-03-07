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
    info("Aquired the `.nd` file and the starting points of the root-tips. Calibrating the data…")
    main(stages, startpoints)
end

function main(stages::Vector{Stage}, startpoints::Vector{Vector{Point}})
    calibstages = stages2calib(stages)
    info("Calibrated the data. Tracking the roots…")
    tracks = trackroot.(calibstages, startpoints)
    info("Tracked the roots. Saving the results…")
    saveit(calibstages, tracks)
    info("Done!")
end

main(ndfile::String, startpoints::Vector{Vector{Point}}) = main(nd2stages(ndfile), startpoints)

end # module

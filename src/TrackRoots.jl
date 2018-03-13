# __precompile__()
ENV["PLOTS_TEST"] = "true"
ENV["GKSwstype"] = "100"
module TrackRoots

export main

using Gtk

head = Gtk.GtkWindow("TrackRoots", 20, 20, false, true, visible=false)

include(joinpath(Pkg.dir("TrackRoots"), "src", "utils.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "stages.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "startPoints.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "calibrates.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "saves.jl"))

function main(stages::Vector{Stage}, startpoints::Vector{Vector{Mark}}, Δx::Float64)
    calibstages = stages2calib(stages, Δx)
    info("Calibrated the data. Tracking the roots…")
    tracks = trackroot.(calibstages, startpoints)
    info("Tracked the roots. Saving the results…")
    saveit(calibstages, tracks)
    info("Done!")
end

function main(; ndfile::String = open_dialog("Pick an `.nd` file", head, ("*.nd",)), stages::Vector{Stage} = nd2stages(ndfile), Δx::T = pixel_width(first(stages))) where T<:Real
# function main(; ndfile::String = open_dialog("Pick an `.nd` file", GtkNullContainer(), ("*.nd",)), stages::Vector{Stage} = nd2stages(ndfile), Δx::T = pixel_width(stages)) where T<:Real
    startpoints = get_startpoints.(stages)
    info("Aquired the `.nd` file and the starting points of the root-tips. Calibrating the data…")
    main(stages, startpoints, Float64(Δx))
end

function main(ndfile::String, startpoints::Vector{Vector{Mark}}) 
    stages = nd2stages(ndfile)
    Δx = pixel_width(first(stages))
    main(stages, startpoints, Δx)
end

end # module

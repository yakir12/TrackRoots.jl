# __precompile__()
ENV["PLOTS_TEST"] = "true"
ENV["GKSwstype"] = "100"
module TrackRoots

export main, batch_main

using NDFiles, CSV, Images

const roottips = joinpath(Pkg.dir("RootTips"), "src", "roottips.jl")
const julia_ndfile = joinpath(tempdir(), "JULIA_NDFILE")

include(joinpath(Pkg.dir("TrackRoots"), "src", "utils.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "calibrates.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "saves.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "nodes.jl"))

function get_startpoints(stage)
    path = joinpath(stage.home, stage.base, "stage $(stage.id)")
    file = joinpath(path, "start_points.csv")
    if isfile(file) 
        a = readcsv(file, Float64)
        n = size(a, 1)
        [Mark(a[i,1], a[i,2]) for i in 1:n]
    else
        Mark[]
    end
end

function main(ndfile::String)
    stages = nd2stages(ndfile)
    startpoints = get_startpoints.(stages)
    Δx = pixel_width(first(stages))
    main(stages, startpoints, Δx, STDERR)
end

function main(stages::Vector{Stage}, startpoints::Vector{Vector{Mark}}, Δx::Float64, output::IO)
    calibstages = stages2calib(stages, Δx)
    output == STDERR && info("Calibrated the data. Tracking the roots…")
    tracks = trackroot.(calibstages, startpoints)
    output == STDERR && info("Tracked the roots. Saving the results…")
    saveit(calibstages, tracks, output)
    output == STDERR && info("Done!")
end

#=function main(; ndfile::String = open_dialog("Pick an `.nd` file", head, ("*.nd",)), stages::Vector{Stage} = nd2stages(ndfile), Δx::T = pixel_width(first(stages))) where T<:Real
# function main(; ndfile::String = open_dialog("Pick an `.nd` file", GtkNullContainer(), ("*.nd",)), stages::Vector{Stage} = nd2stages(ndfile), Δx::T = pixel_width(stages)) where T<:Real
    startpoints = get_startpoints.(stages)
    info("Aquired the `.nd` file and the starting points of the root-tips. Calibrating the data…")
    main(stages, startpoints, Float64(Δx), STDERR)
end=#

# main(ndfile::String, startpoints::Vector{Vector{Mark}}, output::IO) = main(nd2stages(ndfile), startpoints, output)
# batch

function main(ndfile::String, startpoints::Vector{Vector{Mark}}, output::IO) 
    stages = nd2stages(ndfile)
    Δx = pixel_width(first(stages))
    main(stages, startpoints, Δx, output)
end

isnd(file::String) = last(splitext(file)) == ".nd"

function findall_nd(home::String)
    ndfiles = String[]
    for (root, dirs, files) in walkdir(home)
        filter!(isnd, files)
        append!(ndfiles, joinpath.(home, root, files))
    end
    return ndfiles
end

function batch_main(home::String)
    ndfiles = findall_nd(home)
    n = length(ndfiles)
    info("Found $n `.nd` files")
    stagess = [Stage[] for _ in 1:n]
    startpointss = [[Mark[]] for _ in 1:n]
    @showprogress 1 "Collecting start points…" for i in 1:n
        stagess[i] = nd2stages(ndfiles[i])
        startpointss[i] = get_startpoints.(stagess[i])
    end
    @showprogress 1 "Processing the data…" for i in 1:n
        Δx = pixel_width(first(stagess[i]))
        main(stagess[i], startpointss[i], Δx, Base.DevNullStream())
    end
end

end # module

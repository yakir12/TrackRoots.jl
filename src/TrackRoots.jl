module TrackRoots

using Gtk

w = 5
border = 2w
const sz = 1024
outside(i::Float64) = i ≤ 1 + border || i ≥ sz - border
outside(p::T) where T <: AbstractVector = any(outside(i) for i in p)

include(joinpath(Pkg.dir("TrackRoots"), "src", "gui.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "ndfiles.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "saving.jl"))

export main

function main(ndfile::String = open_dialog("Pick an `.nd` file", GtkNullContainer(), ("*.nd",)))
    # GUI to get the root tips
    home, base, files = startstopfiles(ndfile)
    tips = getroots.(files, home, base)
    info("Got the tips of the roots")

    # get the metadata
    md = nd2metadata(ndfile)
    info("Calibration complete")
    # filter empty stages
    k = find(isempty, tips)
    deleteat!(tips, k)
    deleteat!(md.stages, k)
    # track the roots
    rs = map(mytrack, md.stages, tips)
    info("Tracked all the roots")

    # save and plot
    saveit.(md.home, md.base, md.stages, rs)
    info("Finished saving all the files")
end

end # module


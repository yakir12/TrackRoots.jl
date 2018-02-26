module TrackRoots

using Gtk
include(joinpath(Pkg.dir("TrackRoots"), "src", "gui.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "ndfiles.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "saving.jl"))

function main(ndfile::String)
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

# GUI to get the `.nd` file
# ndfile = open_dialog("Pick an `.nd` file", GtkNullContainer(), ("*.nd",))

end # module


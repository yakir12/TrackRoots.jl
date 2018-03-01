module Tips

using Gtk, TrackRoots

include(joinpath(Pkg.dir("TrackRoots"), "src", "gui.jl"))

function get_ndfile_tips()
    ndfile = open_dialog("Pick an `.nd` file", GtkNullContainer(), ("*.nd",))
    info("Getting the tips of the roots…")
    # GUI to get the root tips
    home, base, files = startstopfiles(ndfile)
    tips = getroots.(files, home, base)
    info("Got the tips of the roots")
    return (ndfile, tips)
end

end # module

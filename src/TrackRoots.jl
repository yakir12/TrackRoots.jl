module TrackRoots

using Revise, NDFiles, Tips
ndfile = "/home/yakir/.julia/datadeps/all/7/left-204;mid-184-2-1;right-dr5.nd"
md = nd2metadata(ndfile)
root_tips!.(md.stages)


using ProgressMeter

export main

include(joinpath(Pkg.dir("TrackRoots"), "src", "utils.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "Tips.jl"))
# using Gtk

#=include(joinpath(Pkg.dir("TrackRoots"), "src", "gui.jl"))

function get_ndfile_tips()
    ndfile = open_dialog("Pick an `.nd` file", GtkNullContainer(), ("*.nd",))
    info("Getting the tips of the roots…")
    # GUI to get the root tips
    home, base, files = startstopfiles(ndfile)
    tips = getroots.(files, home, base)
    info("Got the tips of the roots")
    return (ndfile, tips)
end=#

include(joinpath(Pkg.dir("TrackRoots"), "src", "ndfiles.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "saving.jl"))

function main(ndfile::String, tips::Vector{Vector{Point}})
    info("Calibrating the images…")
    md = nd2metadata(ndfile)
    info("Calibration complete. Tracking the roots…")
    rs = map(mytrack, md.stages, tips)
    info("Tracked all the roots. Preparing to save all the results…")
    pm = Progress(sum(st.n*length(r) for (st, r) in zip(md.stages, rs)), 1, "Saving the gif files")
    fun(st::Stage, r::Vector{Track}) = saveit(md.home, md.base, pm, st, r) 
    map(fun, md.stages, rs)
    info("Finished saving all the files")
end

main(ndfile::String) = main(TrackRoots.Tips.get_ndfile_tips(ndfile)...)

main() = main(TrackRoots.Tips.get_ndfile_tips()...)

end # module


# using TrackRoots; ndfile, tips = ("/home/yakir/.julia/datadeps/all/2/204.nd", Array{StaticArrays.SVector{2,Float64},1}[StaticArrays.SVector{2,Float64}[[580.412, 640.352]], StaticArrays.SVector{2,Float64}[]]); TrackRoots.main(ndfile, tips)

# ndfile = "/home/yakir/.julia/datadeps/all/7/left-204;mid-184-2-1;right-dr5.nd"
# tips =  [SVector{2,Float64}[[719.101, 227.214]], SVector{2,Float64}[], SVector{2,Float64}[], SVector{2,Float64}[]]

# main("/home/yakir/.julia/datadeps/all/5/cle44-luc-bfa3.nd")

# tips = 

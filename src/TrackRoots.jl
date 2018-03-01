module TrackRoots

using ProgressMeter

export main

disk(r::Int) = [CartesianIndex(y,x) for y in -r:r for x in -r:r if sqrt(y^2 + x^2) ≤ r]

const sz = 1024
const intensity_radius = 3
const weight_radius = 5
const border = max(intensity_radius, weight_radius)

outside(i::Float64) = i ≤ 1 + border || i ≥ sz - border
outside(p::T) where T <: AbstractVector = any(outside(i) for i in p)

# include(joinpath(Pkg.dir("TrackRoots"), "src", "Tips.jl"))

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

# main() = main(TrackRoots.Tips.get_ndfile_tips()...)

end # module


# using TrackRoots; ndfile, tips = ("/home/yakir/.julia/datadeps/all/2/204.nd", Array{StaticArrays.SVector{2,Float64},1}[StaticArrays.SVector{2,Float64}[[580.412, 640.352]], StaticArrays.SVector{2,Float64}[]]); TrackRoots.main(ndfile, tips)

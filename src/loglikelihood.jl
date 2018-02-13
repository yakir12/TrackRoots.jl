using TrackRoots
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
using DataDeps
RegisterDataDep("test",
                "These are test data including an `nd` file and multiple dark and light timelapse 16 bit TIF images (1.6 GB total).",
                "https://s3.eu-central-1.amazonaws.com/yakirgagnon/roots/test.zip",
                "b98f13389b6ed91ae0c546ccf2d6026b371cb0bf94e750124c62bbf6f680a3a2",
                post_fetch_method=unpack)



folder = "test"
files = readdir(datadep"test")
i = findfirst(x -> last(splitext(x)) == ".nd", files)
md = TrackRoots.nd2metadata(joinpath(datadep"test", files[i]))

# choose stage number
stage_number = 1
# get the stage
st = md.stages[stage_number]

# tips
tip = [
       (671., 822.), # good
       (612., 534.) # bad
      ]

roots = mytrack(st, tip)

@show getfield.(roots, :l)

img = load(st.timelapse[1].dark.path)
using Images
img1 = imadjustintensity(img, quantile(vec(Float64.(img)), [.1, .995]))
img = load(st.timelapse[st.n].dark.path)
img2 = imadjustintensity(img, quantile(vec(Float64.(img)), [.1, .995]))
imgc = map(img1, img2) do i1, i2
    x1 = Float64(i1)
    x2 = Float64(i2)
    RGB(x1, x1, x2)
end
using ImageView, ImageDraw
for r in roots
    draw!(imgc, [ImageDraw.Point(CartesianIndex(round.(Int, p)...)) for p in r.points], eltype(imgc)(1,0,0))
end
imshow(imgc)


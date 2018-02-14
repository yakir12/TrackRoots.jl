using TrackRoots
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
using DataDeps
RegisterDataDep("test",
                "These are test data including an `nd` file and multiple dark and light timelapse 16 bit TIF images (1.6 GB total).",
                "https://s3.eu-central-1.amazonaws.com/yakirgagnon/roots/test.zip",
                "b98f13389b6ed91ae0c546ccf2d6026b371cb0bf94e750124c62bbf6f680a3a2",
                post_fetch_method=unpack)


function testit(root)
   dx = diff(first.(root.points))
   dy = diff(last.(root.points))
   bhat = mean(dx),mean(dy)
   ρhat = cov(dx[1:end-1],dx[2:end])/var(dx), cov(dy[1:end-1],dy[2:end])/var(dy)
   qhat = var(dx)*(1-ρhat[1]^2), var(dy)*(1-ρhat[2]^2)
   return (bhat, ρhat, qhat)
end

folder = "test"
files = readdir(datadep"test")
i = findfirst(x -> last(splitext(x)) == ".nd", files)
md = TrackRoots.nd2metadata(joinpath(datadep"test", files[i]))

# choose stage number
stage_number = 1
# get the stage
st = md.stages[stage_number]

# tips
using ImageFiltering, Images
img = load(st.timelapse[1].dark.path)
img1 = imfilter(img, Kernel.gaussian(4))
p = findlocalmaxima(img1)
# sort!(p, by=i -> img[i],rev=true)
tip = [(Float64.([ti.I...])...) for ti in p]
filter!(x -> !outside(Vector(Point(x))), tip)

tips = Dict("good" => [(671., 822.), (535., 379.), (676., 221.), (620., 921.), (652., 992.), (714., 669.), (581., 638.), (592., 226.)],
            "bad" => [[(612., 534.), (59., 753.)]; tip[1:6]])

roots = Dict(k => mytrack(st, v) for (k,v) in tips)

using DataFrames
df = DataFrame(root = "good", logLikelihood = 0.0, brightness = 0.0, err = 0.0, bhat1 = 0.0, bhat2 = 0.0, ρhat1 = 0.0, ρhat2 = 0.0, qhat1 = 0.0, qhat2 = 0.0)
for (k,v) in roots
    for r in v
        bhat, ρhat, qhat = testit(r)
        push!(df, (k, r.l, r.I, r.err, bhat..., ρhat..., qhat...))
    end
end
deleterows!(df, 1)

aggregate(df, :root, mean)

using Query, Plots, StatPlots

p = []
good = df[df[:root] .== "good",:]
bad = df[df[:root] .== "bad",:]
for f in [:logLikelihood, :brightness, :err, :bhat1, :bhat2, :ρhat1, :ρhat2, :qhat1, :qhat2]
    p1 = violin(good[f], side=:right, marker=(0.2,:blue,stroke(0)), label="good", ylabel = string(f), leg=false)
    violin!(bad[f], side=:left, marker=(0.2,:red,stroke(0)), label="bad")
    push!(p, p1)
end
plot(p..., size=(800,800))



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
for (c,k) in zip([(1,0,0), (1,0,1)], ["bad", "good"]), r in roots[k]
    draw!(imgc, [ImageDraw.Point(CartesianIndex(round.(Int, p)...)) for p in r.points], eltype(imgc)(c...))
end
imshow(imgc)



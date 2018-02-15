using TrackRoots
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))

using DataDeps
RegisterDataDep("all",
                "These are all 8 folders with their `nd` files and multiple dark and light timelapse 16 bit TIF images (7.8 GB total).",
                "https://s3.eu-central-1.amazonaws.com/yakirgagnon/roots/eight_folders.zip",
                "c316452c19e3c639737821581d18e45654980e04e0244f3d43e30d47d3e81f11",
                post_fetch_method=unpack)

i = 2
files = readdir(joinpath(datadep"all", string(i)))
j = findfirst(x -> last(splitext(x)) == ".nd", files)
md = TrackRoots.nd2metadata(joinpath(datadep"all", string(i), files[j]))


radius = 15
border2 = 2radius
inside(i::Int) = 1 + border2 < i < sz - border2
inside(p::Index) = all(inside.(p.I))
x = [x for x in -radius:radius for y in -radius:radius if sqrt(x^2 + y^2) ≤ radius]
y = [y for x in -radius:radius for y in -radius:radius if sqrt(x^2 + y^2) ≤ radius]
XY2 = hcat(Float64.(x), Float64.(y))'
window2 = [CartesianIndex(xi, yi) for (xi,yi) in zip(x,y)]
V2 = zeros(Gray{N0f16}, length(window2))
Y2 = zeros(length(window2))
function adjust(img::Image, ind::Index)
    for (i, wi) in enumerate(window2)
        V2[i] = img[wi + ind]
    end
    mu = mean(V2)
    for i in eachindex(Y2)
        Y2[i] = max(V2[i] - mu, 0.0) 
    end
    μ = mean(XY2, Weights(Y2), 2)
    ind + CartesianIndex(round.(Int, μ)...)
end
using ImageFiltering, Images
function find_candidates(img)
    img1 = imfilter(img, Kernel.gaussian(4))
    threshold = quantile(vec(img1), 0.85)
    p = findlocalmaxima(max.(img1, threshold))
    filter!(inside, p)  
    p = unique(adjust(img, i) for i in p)
    filter(inside, p)  
end

img = load(md.stages[1].timelapse[1].dark.path)
p = find_candidates(img)

img = imadjustintensity(img, quantile(vec(Float64.(img)), [.1, .995]))
imgc = RGB.(img)
using ImageDraw
draw!(imgc, ImageDraw.CirclePointRadius.(p, 3), eltype(imgc)(1,0,0))
save("a.png", imgc)








using Makie, GeometryTypes, Colors
i = 9
files = readdir(joinpath(datadep"all", string(i)))
j = findfirst(x -> last(splitext(x)) == ".nd", files)
md = TrackRoots.nd2metadata(joinpath(datadep"all", string(i), files[j]))
img = load(md.stages[1].timelapse[1].dark.path)
img = imadjustintensity(img, quantile(vec(Float64.(img)), [.1, .995]))
scene = Scene(resolution=(sz, sz))
heatmap(img)
center!(scene, 0)
cam = scene[:screen].cameras[:orthographic_pixel]
Makie.add_mousebuttons(scene)
clicks = to_node(Point2f0[])
pos = lift_node(scene, :mousebuttons) do buttons
    if length(buttons) == 1 && first(buttons) == Mouse.left
        pos = to_world(Point2f0(to_value(scene, :mouseposition)), cam)
        # awkward! one push! for adding to clicks, another to update the node!
        push!(clicks, push!(to_value(clicks), pos))
    end
    return 
end
scatter(clicks, markersize = 10)

p = [CartesianIndex{2}(round(Int, sz - i[2] + 1), round(Int, i[1])) for i in clicks.signal.value]
imgc = RGB.(img)
using ImageDraw
draw!(imgc, ImageDraw.CirclePointRadius.(p, 3), eltype(imgc)(1,0,0))
save("a.png", imgc)
@show p


good = Vector{Vector{CartesianIndex{2}}}(8)
good[1] = CartesianIndex{2}[CartesianIndex{2}((773, 913)), CartesianIndex{2}((802, 755)), CartesianIndex{2}((830, 708)), CartesianIndex{2}((867, 526)), CartesianIndex{2}((871, 321)), CartesianIndex{2}((746, 264)), CartesianIndex{2}((956, 121))]
good[2] = CartesianIndex{2}[CartesianIndex{2}((649, 993)), CartesianIndex{2}((618, 919)), CartesianIndex{2}((673, 821)), CartesianIndex{2}((713, 670)), CartesianIndex{2}((582, 640)), CartesianIndex{2}((535, 379)), CartesianIndex{2}((591, 227)), CartesianIndex{2}((674, 221))]
good[3] = CartesianIndex{2}[CartesianIndex{2}((524, 906)), CartesianIndex{2}((471, 521)), CartesianIndex{2}((356, 64))]
good[4] = CartesianIndex{2}[CartesianIndex{2}((538, 138)), CartesianIndex{2}((555, 260)), CartesianIndex{2}((430, 381)), CartesianIndex{2}((542, 527)), CartesianIndex{2}((537, 575)), CartesianIndex{2}((523, 692)), CartesianIndex{2}((635, 797)), CartesianIndex{2}((460, 883)), CartesianIndex{2}((593, 947))]
good[5] = CartesianIndex{2}[CartesianIndex{2}((835, 965)), CartesianIndex{2}((720, 955)), CartesianIndex{2}((854, 734)), CartesianIndex{2}((760, 418))]
good[6] = CartesianIndex{2}[CartesianIndex{2}((645, 948)), CartesianIndex{2}((455, 698)), CartesianIndex{2}((527, 345))]
good[7] = CartesianIndex{2}[CartesianIndex{2}((720, 229)), CartesianIndex{2}((925, 486))]
good[8] = CartesianIndex{2}[CartesianIndex{2}((924, 535))]
using Distances
bad = Vector{Vector{CartesianIndex{2}}}(8)
for i in 1:8
    # i = 1
    files = readdir(joinpath(datadep"all", string(i)))
    j = findfirst(x -> last(splitext(x)) == ".nd", files)
    md = TrackRoots.nd2metadata(joinpath(datadep"all", string(i), files[j]))
    img = load(md.stages[1].timelapse[1].dark.path)
    ps = find_candidates(img)
    y1 = first.(getfield.(good[i], :I))
    x1 = last.(getfield.(good[i], :I))
    y2 = first.(getfield.(ps, :I))
    x2 = last.(getfield.(ps, :I))
    d = pairwise(Euclidean(), hcat(y1, x1)', hcat(y2, x2)')
    kill = Int[]
    for j in 1:length(ps)
        if any(d[:,j] .< radius)
            push!(kill, j)
        end
    end
    deleteat!(ps, kill)
    bad[i] = ps
#=img = imadjustintensity(img, quantile(vec(Float64.(img)), [.1, .995]))
imgc = RGB.(img)
using ImageDraw
draw!(imgc, ImageDraw.CirclePointRadius.(ps, 3), eltype(imgc)(1,0,0))
save("a.png", imgc)=#
end


function testit(root)
   dx = diff(first.(root.points))
   dy = diff(last.(root.points))
   bhat = mean(dx),mean(dy)
   ρhat = cov(dx[1:end-1],dx[2:end])/var(dx), cov(dy[1:end-1],dy[2:end])/var(dy)
   qhat = var(dx)*(1-ρhat[1]^2), var(dy)*(1-ρhat[2]^2)
   return (bhat, ρhat, qhat)
end



using DataFrames
df = DataFrame(root = "good", logLikelihood = 0.0, brightness = 0.0, err = 0.0, bhat1 = 0.0, bhat2 = 0.0, ρhat1 = 0.0, ρhat2 = 0.0, qhat1 = 0.0, qhat2 = 0.0)
for i = 1:8
    # i = 1
    files = readdir(joinpath(datadep"all", string(i)))
    j = findfirst(x -> last(splitext(x)) == ".nd", files)
    md = TrackRoots.nd2metadata(joinpath(datadep"all", string(i), files[j]))
    st = md.stages[1]
    p = vcat(good[i], bad[i])
    groups = vcat(fill("good", length(good[i])), fill("bad", length(bad[i])))
    roots = mytrack(st, p)
    for (r,g) in zip(roots, groups)
        bhat, ρhat, qhat = testit(r)
        push!(df, (g, r.l, r.I, r.err, bhat..., ρhat..., qhat...))
    end
end
deleterows!(df, 1)
deleterows!(df, find(abs.(df[:logLikelihood]) .> 500))






using ImageDraw
for i in 1:8
    files = readdir(joinpath(datadep"all", string(i)))
    j = findfirst(x -> last(splitext(x)) == ".nd", files)
    md = TrackRoots.nd2metadata(joinpath(datadep"all", string(i), files[j]))
    img = load(md.stages[1].timelapse[1].dark.path)
    img = imadjustintensity(img, quantile(vec(Float64.(img)), [.1, .995]))
    imgc = RGB.(img)
    draw!(imgc, ImageDraw.CirclePointRadius.(ImageDraw.Point.(good[i]), 4), eltype(imgc)(1,0,0))
    draw!(imgc, ImageDraw.CirclePointRadius.(ImageDraw.Point.(bad[i]), 2), eltype(imgc)(0,1,0))
    save("/home/yakir/tmp/$i.png", imgc)
end


save("/tmp/goodbad.jld", "good", good, "bad", bad)


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
df[:bhat] = (df[:bhat1] .+ df[:bhat2])/2
df[:ρhat] = (df[:ρhat1] .+ df[:ρhat2])/2
df[:qhat] = (df[:qhat1] .+ df[:qhat2])/2
p = []
dfgood = df[df[:root] .== "good",:]
dfbad = df[df[:root] .== "bad",:]
vars = [:logLikelihood, :brightness, :err, :bhat, :ρhat, :qhat]
vars = [:logLikelihood, :brightness, :err, :bhat1, :bhat2, :ρhat1, :ρhat2, :qhat1, :qhat2]
for f in vars
    p1 = violin(dfgood[f], side=:right, marker=(0.2,:blue,stroke(0)), label="good", ylabel = string(f), leg=false)
    violin!(dfbad[f], side=:left, marker=(0.2,:red,stroke(0)), label="bad")
    push!(p, p1)
end
plot(p..., size=(800,800))

labels = df[:root]
features = Array(df[:, vars])
using DecisionTree
m= build_tree(labels[1:2:end], features[1:2:end, :])
# prune tree: merge leaves having >= 90% combined purity (default: 100%)
m= prune_tree(m, 0.9)
# apply learned model
[labels [apply_tree(m, features[i, :]) for i in 1:length(labels)]]



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



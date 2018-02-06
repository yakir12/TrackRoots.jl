# moves 1.5 pixels per frame => 0.35 mm per day
# using Unitful, ImageView, Images, TrackRoots, ImageSegmentation, IdentityRanges, UnitfulAngles, Plots, Interpolations, OffsetArrays
# using TrackRoots, Images, Plots, Colors
using Unitful, UnitfulAngles, Images, TrackRoots, Plots, OffsetArrays, StaticArrays, StatsBase, Distributions, Dierckx, HDF5, ImageDraw
import Unitful: °
gr(legend=false)
# constants 
const sz = (1024, 1024) # image size
const W = 7 # window size
β = 80° # the opening angle for the search
const win = -W:W 
const XY = hcat(vec(Base.vect.(Float64.(win)', Float64.(win)))...) 
XY2 = hcat(vec(Base.vect.(Float64.(win), Float64.(win)'))...) 
const offset = unique(CartesianIndex(round(Int, r*sin(θ)), round(Int, r*cos(θ))) for r in linspace(0,5,20), θ in linspace(90° - β, 90° + β, 20))
const circle = unique(CartesianIndex(y, x) for y in -2:2, x in -2:2 if sqrt(y^2 + x^2) ≤ 2)
y = 1
x = 1
for w in (CartesianIndex(W,W), offset, circle)
    y += maximum(abs.(getindex.(w, 1)))
    x += maximum(abs.(getindex.(w, 2)))
end
const padsize = (y,x)
const Frame = OffsetArray{N0f16,2,Matrix{N0f16}}
const Frames = OffsetArray{N0f16,3,Array{N0f16,3}}
const Coordinate = SVector{2,Float64}
const root_number_color = RGB{Float64}(0.126446,0.135833,0.785339)
const root_path_color = RGBA{Float64}(1,0,0,.5)
const blueish = RGB{N0f8}(0,0.388,0.98)
const pinkish = RGB{N0f8}(0,0.804,0.494)
bw = [RGB{Float64}(i ,i , i) for i in 0:1]
const purple = RGB(191/255,125/255,191/255)#distinguishable_colors(3, bw)[end]
tohours(t::T) where T<:Base.Dates.TimePeriod = t/convert(T, Base.Dates.Hour(1))
function load_timelapse(st::TrackRoots.Stage, channel::Symbol)
    imgs = OffsetArray(N0f16, 1:st.n, 1-padsize[1]:sz[1]+padsize[1], 1-padsize[2]:sz[2]+padsize[2])
    for i in 1:st.n
        imgs[i,1:sz[1],1:sz[2]] = load(getfield(st.timelapse[i], channel))
    end
    return imgs
end
function rsqr(v::Vector{Float64}, vl::Vector{Float64})
    res = 0.0
    tot = 0.0
    μ = mean(v)
    for (i,j) in zip(v, vl)
        res += (i - j)^2
        tot += (i - μ)^2
    end
    return 1 - res/tot
end
function symmetric(x::Array{Float64,2}, minsymmetry::T) where T<:Real
    r = x[1]/x[2]
    r = r < 1 ? r : 1/r
    return r > minsymmetry
end
function get_μ_Σ(img::Matrix{N0f16})
    v = float64.(vec(img))
    lt = mean(v)
    v -= lt
    clamp!(v, 0, 1)
    μ, Σ = mean_and_var(XY, Weights(v), 2, corrected=false)
    return (μ, Σ, v)
end
function test_locate(img::Matrix{N0f16}, minsymmetry::T, minσ::Y, maxσ::U, minrsqr::I) where {T<:Real, Y<:Real, U<:Real, I<:Real}
    μ, Σ, v = get_μ_Σ(img)
    if symmetric(Σ, minsymmetry) 
        σ = sqrt(mean(Σ))
        if minσ < σ < maxσ 
            vl = pdf(MvNormal(vec(μ), σ), XY)
            r² = rsqr(v/sum(v), vl)
            if r² > minrsqr
                return Nullable(Coordinate(μ...))
            end
        end
    end
    return Nullable{Coordinate}()
end
function test_locate(img::Matrix{N0f16}, minσ::T, maxσ::Y) where {T<:Real, Y<:Real}
    μ, Σ, _ = get_μ_Σ(img)
    σ = sqrt(mean(Σ))
    if minσ < σ < maxσ 
        return Nullable(Coordinate(μ...))
    end
    return Nullable{Coordinate}()
end
function find_max(I::Frame, p::Coordinate)
    rp = round.(Int, p)
    i = CartesianIndex(rp[2], rp[1])
    io = CartesianIndex(1,1)
    M = N0f16(0)
    for o in offset
        _io = i + o
        _M = I[_io]
        if _M > M
            io, M = _io, _M
        end
    end
    return io
end
struct Root
    coordinates::Vector{Coordinate}
    growing::Ref{Bool}
    function Root(coordinate::Coordinate, n::Int) 
        coordinates = [coordinate]
        sizehint!(coordinates, n)
        return new(coordinates, true)
    end
end
function initialise(img::Frame, n::Int; minsymmetry = 0.3, minrsqr = 0.8, minσ = 0.5, maxσ = 4.5)
    img = imfilter(img, Kernel.gaussian(3))
#=img, n = dark_imgs[1,:,:], st.n
minsymmetry = 0.3
minrsqr = 0.8
minσ = 0.5
maxσ = 4.5
minrsqr=0.6
img = imfilter(img, Kernel.gaussian(3))
i = findlocalmaxima(img)
sort!(i, by=x->img[x], rev=true)
# i = i[1:25]
μ = mean(img)
filter!(x -> img[x] > μ, i)
# img = RGB.(padarray(Gray.(img), Fill(0, (10,10))))
img2 = RGB.(Gray.(img))
draw!(img2, CirclePointRadius.(Point.(i), 3), RGB{eltype(img)}(1,0,0))
imshow(img2)=#
    @assert 0 ≤ minsymmetry ≤ 1 "minimum symmetry has to be between zero and one"
    @assert 0 ≤ minrsqr ≤ 1 "minimum r² has to be between zero and one"
    @assert 0 ≤ minσ < maxσ "minimum σ has to be between zero and maximum σ"
    roots = Root[]
    for i in CartesianRange(sz)
        i = CartesianIndex(1,1)
        v = img[i[1] + win, i[2] + win]
        if all(img[i] ≥ vi for vi in v)
            p = test_locate(v, minsymmetry, minσ, maxσ, minrsqr)
            if !isnull(p)
                r = Root(get(p) + Coordinate(i.I[2], i.I[1]), n)
                push!(roots, r)
            end
        end
    end
    return roots
end
function grow!(imgs::Frames, roots::Vector{Root}; minσ = 0.5, maxσ = 4.5)
    @assert 0 ≤ minσ < maxσ "minimum σ has to be between zero and maximum σ"
    for frame in 2:st.n
        img = imgs[frame,:,:]
        for r in roots
            if r.growing.x
                i = find_max(img, r.coordinates[frame - 1])
                v = img[i[1] + win, i[2] + win]
                p = test_locate(v, minσ, maxσ)
                if !isnull(p)
                    push!(r.coordinates, get(p) + Coordinate(i.I[2], i.I[1]))
                else
                    r.growing.x = false
                end
            end
        end
    end
end
function smooth_distances(r::Vector{Coordinate})
    t = 1:length(r)
    x = first.(r)
    y = last.(r)
    X = hcat(x,y)'
    p = ParametricSpline(t, X, s=10)
    Xs = p(t)
    xl = vec(Xs[1,:])
    yl = vec(Xs[2,:])
    d = cumsum([norm(derivative(p, i)) for i in t])
    d -= d[1]
    return ([Coordinate(x,y) for (x,y) in zip(xl, yl)], d)
end
function get_intensities(imgs::Frames, roots::Vector{Root}, n::Int, Δ::Float64)
    masks = [[similar(circle) for i in 1:length(r.coordinates)] for r in roots]
    distances = Vector{Vector{Float64}}(length(roots))
    coordinates = [Vector{Coordinate}(length(r.coordinates)) for r in roots]
    for (i,root) in enumerate(roots)
        coordinates[i], distances[i] = smooth_distances(root.coordinates)
        for (j, xy) in enumerate(coordinates[i])
            xyr = round.(Int, xy)
            yxc = CartesianIndex(xyr[2], xyr[1])
            masks[i][j] = yxc .+ circle
        end
    end
    distances *= Δ
    intensities = [Matrix{Float64}(length(r.coordinates), length(r.coordinates)) for r in roots]
    for frame in 1:n
        for (i,root) in enumerate(masks)
            if frame ≤ length(root)
                for (j,xy) in enumerate(root)
                    intensities[i][frame,j] = sum(Float64, imgs[frame, xy])
                end
            end
        end
    end
    return (distances, intensities, coordinates)
end
function filter_roots!(roots::Vector{Root}; remove=Int[], keep=Int[])
    if !isempty(remove)
        @assert isempty(keep) "supply roots to remove OR roots to keep, not both"
        deleteat!(roots, remove)
    elseif !isempty(keep)
        remove = setdiff(1:length(roots), keep)
        deleteat!(roots, remove)
    end
end
function get_images(l::Matrix{N0f16}, d::Matrix{N0f16})
    l = adjust_gamma(imadjustintensity(l, quantile(vec(l), [.01, .99])), 1/2.2)
    d = adjust_gamma(imadjustintensity(d, quantile(vec(d), [.01, .999])), 1/2.2)
    da = [coloralpha(purple, gray(di)) for di in d]
    return (l, da)
end
function plot_initiated(l1::Matrix{N0f16}, l2::Matrix{N0f16}, roots::Vector{Root}, home::String, base::String, stage_number::Int)
    l1 = imadjustintensity(l1)
    l2 = imadjustintensity(l2)
    img = colorview(RGB, l2, l1, l2)
    plot(img, size=sz, aspect_ratio=:equal, legend=false, axis=false)
    for (i, p) in enumerate(roots)
        x, y = p.coordinates[1]
        Plots.annotate!(x, y, text(string(i), 25, root_number_color))
    end
    name = joinpath(home, "$base-$stage_number-initiated.png")
    png(name)
    info("An image of the initiated roots is at $name")
end
function save2gif(light_imgs::Frames, times::StepRange{DateTime,Base.Dates.Millisecond}, roots::Vector{Root}, distances::Vector{Vector{Float64}}, ints::Vector{Matrix{Float64}}, coordinates::Vector{Vector{Coordinate}}, home::String, base::String, stage_number::Int)
    # times = st.times
    milliseconds = times - times[1]
    hours = tohours.(milliseconds)
    for ri in 1:length(roots)
        # ri = 1
        d = distances[ri]
        z = ints[ri]
        xX = round.(Int, extrema(first.(coordinates[ri])))
        yY = round.(Int, extrema(last.(coordinates[ri])))
        xX = [xX...] .+ [-padsize[1], padsize[2]]
        yY = [yY...] .+ [-padsize[1], padsize[2]]
        aspect_ratio = diff(yY)[1]/diff(xX)[1]
        nd = length(d)
        l = RGB.(Gray.((light_imgs[1:nd, yY[1]:yY[2], xX[1]:xX[2]])))
        l = imadjustintensity(l)
        # xy = round.(Int, coordinates[ri])
        xy = [round.(Int, xy) for xy in coordinates[ri]]
        for i in 1:nd
            ind = [Point(x - xX[1], y - yY[1]) for (x,y) in xy[1:i]] 
            draw!(view(l, i,:,:), Path(ind), RGB{N0f16}(1,0,0))
        end
        ylim = extrema(z)
        anim = @animate for i in 1:nd
            h1 = heatmap(l[i,:,:], aspect_ratio=aspect_ratio, legend=false, title=string(round(times[i], Dates.Hour(1))), yflip=true, color=:grays, axis=false)
            h2 = plot(d, z[i,:], color=pinkish, ylim=ylim, xlabel="Root distance (mm)",yticks=nothing)
            h3 = plot(z[:,nd - i + 1], hours[1:nd], color=blueish, xlim=ylim, ylabel="Time (hrs)", xticks=nothing)
            h4 = heatmap(d, hours, z, xlabel="Root distance (mm)", ylabel="Time (hrs)", legend=false)
            plot!(d[[1, end]], [hours[i], hours[i]], color=pinkish)
            plot!([d[nd - i + 1], d[nd - i + 1]], hours[[1, nd]], color=blueish)
            plot(h2, h1, h4, h3)
        end
        name = joinpath(home, "$base-$stage_number-root_number-$ri.gif")
        gif(anim, name, fps = 30)
        info("A gif image of root number $ri is at $name")
    end
end
function save2hdf5(times::StepRange{DateTime,Base.Dates.Millisecond}, distances::Vector{Vector{Float64}}, ints::Vector{Matrix{Float64}}, home::String, base::String, stage_number::Int, nd_file::String) 
    name = joinpath(home, "$base-$stage_number-data.h5")
    h5open(name, "w") do o
        home = g_create(o, "roots")
        attrs(home)["Description"] = "These are the distances, times, and intensities for each of the tracked roots in satge number $stage_number in $nd_file."
        home["times"] = string.(times)
        eachroot = g_create(home, "roots")
        attrs(eachroot)["Description"] = "Each root has an 'intensities' matrix with n rows and m columns. Each row is one temporal slice. The individual times are given in the 'times' vector and apply to all roots. Each column is one root distance. These distances are given in the 'distances' vector and apply only to that specific root."
        for i in 1:length(distances)
            root = g_create(eachroot, "root $i")
            root["distances"] = collect(distances[i])
            root["intensities"] = ints[i]
        end
        info("An HDF5 file of the distances, times, and intensities of the roots from stage number $stage_number and $nd_file is at $name")
    end
end



folder = "/home/yakir/datasturgeon/projects/guy wachsman"
mds = String[]
for (roo, dirs, files) in walkdir(folder)
    for file in files
        _, ext = splitext(file)
        if ext == ".nd"
            md = joinpath(folder, roo, file)
            push!(mds, md)
        end
    end
end

# choose nd file
nd_file = mds[5]
## get stages
md = TrackRoots.nd2metadata(nd_file)
# choose stage number
stage_number = 1
## get the stage
st = md.stages[stage_number]
## get the images
dark_imgs = load_timelapse(st, :dark)
light_imgs = load_timelapse(st, :light)
## get the initiated roots

roots = initialise(dark_imgs[1,:,:], st.n, minsymmetry = 0, minrsqr = 0, minσ = 0, maxσ = Inf)#minrsqr=0.6, minsymmetry = 0.3, minrsqr = 0.5, minσ = 1, maxσ = 2)
# function initialise(img::Frame, n::Int; minsymmetry = 0.3, minrsqr = 0.8, minσ = 0.5, maxσ = 4.5)

## plot an image of the initiated roots
plot_initiated(light_imgs[1, 1:sz[1], 1:sz[2]], light_imgs[st.n, 1:sz[1], 1:sz[2]], roots,md.home, md.base, stage_number) 

# choose dead roots
filter_roots!(roots, keep=[6, 15, 27])
## grow roots
grow!(dark_imgs, roots)

## get intensities and distances
distances, ints, coordinates = get_intensities(dark_imgs, roots, st.n, md.Δ)

## save it to a gif
save2gif(light_imgs, st.times, roots, distances, ints, coordinates, md.home, md.base, stage_number)

## save it to a hdf5
save2hdf5(st.times, distances, ints, md.home, md.base, stage_number, nd_file)



#=img = zeros(Gray{Float64}, 400,400)
for i in CartesianRange(size(img))
    if norm([i.I...] - 200) < 100
        img[i] = 1
    end
end
crop = (200:300, 200:300)
l = img[crop...]
h1 = plot(img, title="full")
p1 = [200,200]
α = rand()*(.5*pi)
I = [cos(α), sin(α)]
I /= norm(I)
p2 = p1 + I*100
x = [p1[1], p2[1]]
y = [p1[2], p2[2]]
plot!(h1, x, y)
h2 = plot(l, title="cropped?")
plot!(h2, x - crop[1][1], y - crop[2][1])
plot(h1, h2, aspect_ratio=1)
png("kaka")=#



#=
l1 = light_imgs[1, 1:sz[1], 1:sz[1]]
l2 = light_imgs[st.n, 1:sz[1], 1:sz[1]]
f(img) = imadjustintensity(img)
l1 = f(l1)
l2 = f(l2)
img = colorview(RGB, l2, l1, l2)


img = load("julia.png")
bw = Gray.(img)
m = Float64.(bw)
h1 = heatmap(m, title="full")
h2 = heatmap(m, ylim=(200,300), xlim=(100,200), title="cropped!", color=:grays)
plot(h1, h2, aspect_ratio=1)
png("kaka")



save("kaka.png", img)


d = dark_imgs[st.n, 1:sz[1], 1:sz[1]]
l = adjust_gamma(imadjustintensity(l, quantile(vec(l), [.01, .99])), 1/2.2)
d = adjust_gamma(imadjustintensity(d, quantile(vec(d), [.01, .999])), 1/2.2)
# img = Gray.(l) .+ coloralpha.(purple, d) 
# img = imadjustintensity(img)
img = colorview(RGB, l, clamp01.(l-d), d)
# img = clamp01.(l .+ d)*purple
# img = colorview(RGB, l + red(purple)*d, l + green(purple)*d, l + blue(purple)*d)
# img = adjust_gamma(imadjustintensity(img, quantile(vec(channelview(img)), [.01, .9995])), 1/2.2)
save("kaka.png", img)=#

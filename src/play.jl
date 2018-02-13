using Revise
using TrackRoots
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
using DataDeps
RegisterDataDep("all",
                "These are all 8 folders with their `nd` files and multiple dark and light timelapse 16 bit TIF images (7.8 GB total).",
                "https://s3.eu-central-1.amazonaws.com/yakirgagnon/roots/eight_folders.zip",
                "c316452c19e3c639737821581d18e45654980e04e0244f3d43e30d47d3e81f11",
                post_fetch_method=unpack)
tips = [(744, 263), (671, 822), (471, 523), (556, 258), (761, 416), (525, 344), (719,227), (922, 534)]
tips = map(tips) do t
    (Float64.([first(t), last(t)])...)
end


# s = Vector{typeof(1u"mm"/1u"ms")}()
# df = DataFrame(species = "0", speed = 0.0)
# cf = DataFrame(species = "0", cov = 0.0)

rr = Dict()

for i in 1:8

    # i = 2
    files = readdir(joinpath(datadep"all", string(i)))
    j = findfirst(x -> last(splitext(x)) == ".nd", files)
    md = TrackRoots.nd2metadata(joinpath(datadep"all", string(i), files[j]))
    # choose stage number
    stage_number = 1
    ## get the stage
    st = md.stages[stage_number]
    # img = load(st.timelapse[1].dark.path)
    # img = imadjustintensity(img, quantile(vec(Float64.(img)), [.1, .995]))
    # imshow(img)

    # get the mean time in milliseconds
    tip = tips[i]
    tip = [tip]

    #=using ImageFiltering, Images
    img = load(st.timelapse[1].dark.path)
    img1 = imfilter(img, Kernel.gaussian(4))
    p = findlocalmaxima(img1)
    # b = blob_LoG(img[1:sz,1:sz], linspace(5,40,5))
    # p = getfield.(b, :location)
    μ = quantile(vec(img), 0.95)
    filter!(i -> img[i] > μ, p)
    tip = [(Float64.([ti.I...])...) for ti in p]
    filter!(x -> !outside(Vector(Point(x))), tip)
    shuffle!(tip)
    tip = tip[1:5]
    if all(t ≠ tips[i] for t in tip)
        push!(tip, tips[i])
    end
    push!(tip, (676., 221.))

    tip = []
    push!(tip, (592., 226.))=#

    roots = mytrack(st, tip)


#=n = 30
    for r in roots
        dyx = diff(r.points[1:n])
        l = sqrt.(sum.(abs2, dyx))
        a = dyx./l
        av = sqrt(mean(first.(a))^2 + mean(last.(a))^2)
        dv = var(l)
        @show [mean(l), dv, av]
    end=#

    #=s = md.Δx*sqrt.(sum.(abs2, diff(roots[1].points)))./[1u"ms"*(st.timelapse[i+1].dark.time - st.timelapse[i].dark.time) for i in 1:length(roots[1].points) - 1]
    for si in s
        s2 = ustrip(uconvert(u"mm"/u"d", si))
        push!(df, (string(i), s2))
    end=#
    rr[i] = [(st.Δx*roots[1].points[i], uconvert(u"d", 1u"ms"*st.timelapse[i].dark.time)) for i in 1:length(roots[1].points)]

    #=s = md.Δx*diff(first.(roots[1].points))./[1u"ms"*(st.timelapse[i+1].dark.time - st.timelapse[i].dark.time) for i in 1:length(roots[1].points) - 1]
    for si in s
        s2 = ustrip(uconvert(u"mm"/u"d", si))
        push!(df, (string(i), s2))
    end

    s = md.Δx*diff(first.(roots[1].points))./[1u"ms"*(st.timelapse[i+1].dark.time - st.timelapse[i].dark.time) for i in 1:length(roots[1].points) - 1]
    c = cov(s[1:end-1], s[2:end])
    c2 = ustrip(uconvert(u"mm^2"/u"d^2", c))
    push!(cf, (string(i), c2))=#

    img = load(st.timelapse[1].dark.path)
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

end




# deleterows!(df, 1)

# using StatPlots

# df2 = df[df[:speed] .< 600, :]
# @df df2 violin(:species,:speed,marker=(0.2,:blue,stroke(0)))
# @df df2 boxplot!(:species,:speed,marker=(0.3,:orange,stroke(2)))

# s2 = ustrip.(uconvert.(u"mm"/u"d", s))
# histogram(s2, xlim=(-1,12))

yx = Dict(k => ustrip.(first.(rr[k])) for k in 2:8)
t = Dict(k => ustrip.(last.(v)) for (k,v) in rr)

y = [first(i) for v in values(yx) for i in v]

dy = mean([var(diff(diff(first.(v))./diff(t[k]))) for (k,v) in yx])
dx = mean([var(diff(diff(last.(v))./diff(t[k]))) for (k,v) in yx])

c = Float64[]
for (k,v) in yx
    dy = diff(first.(v))./diff(t[k])
    push!(c, cov(dy[1:end-1], dy[2:end]))
end

rho = Float64[]
for (k,v) in yx
    dy = diff(first.(v))./diff(t[k])
    c = cov(dy[1:end-1], dy[2:end])
    v = var(dy)
    push!(rho, c/v)
end


# for y
y = [ 
 0.670618
 0.810991
 0.168168
 0.926173
 0.952638
 0.86647 
 0.979771
]
 # for x
 x = [
 0.650139 
 0.672052 
 0.637448 
 0.411515 
 0.292202 
 0.0170648
 0.803177 
]
mean(x)
mean(y)


histogram(dy)
mean_and_var(dy)







ρ = 0.6
n = 2000
q = 3.5

ϵ = √(q)*randn(n)
b = 2.0

dy = zeros(n)
dy0 = b
for i in 2:n
   dy[i] = ρ*dy[i-1] + (1-ρ)*b + ϵ[i]
end


bhat = mean(dy)
@show b, bhat

ρhat = cov(dy[1:end-1],dy[2:end])/var(dy)
@show ρ, ρhat

qhat = var(dy)*(1-ρhat^2)
@show q, qhat;



dyx = diff(points)
l = sqrt.(sum.(abs2, dyx))
a = dyx./l
sqrt(mean(first.(a))^2 + mean(last.(a))^2)

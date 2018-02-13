using TrackRoots, DataDeps, Kalman, Images, StaticArrays, Unitful, StatsBase, OffsetArrays

const Point = SVector{2,Float64}
speed_real = 0.35u"mm"/1u"d"

RegisterDataDep("all",
                "These are all 8 folders with their `nd` files and multiple dark and light timelapse 16 bit TIF images (7.8 GB total).",
                "https://s3.eu-central-1.amazonaws.com/yakirgagnon/roots/eight_folders.zip",
                "c316452c19e3c639737821581d18e45654980e04e0244f3d43e30d47d3e81f11",
                post_fetch_method=unpack)

files = readdir(datadep"all/3")
i = findfirst(x -> last(splitext(x)) == ".nd", files)

md = TrackRoots.nd2metadata(joinpath(datadep"all/3", files[i]))

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
## get the stage
st = md.stages[stage_number]
# get the mean time in milliseconds

w = 5
XY = hcat(vec(Base.vect.(Float64.(-w:w), Float64.(-w:w)'))...)
window = CartesianRange(CartesianIndex(-w, -w), CartesianIndex(w, w))

V = OffsetArray(Gray{N0f16}, -w:w, -w:w)
Y = zeros((2w + 1)^2)


function image_feedback(img, p::CartesianIndex{2})
    for i in window
        V[i] = img[i + p]
    end
    mu = mean(V)
    for (i,j) in zip(eachindex(Y), eachindex(V))
        Y[i] = max(V[j] - mu, 0.0) 
    end
    μ, Σ = mean_and_var(XY, Weights(Y), 2, corrected=false)
    return (Point([p.I...] + μ), sqrt(sum(diag(Σ))))
end


# img = rand(Gray{N0f16}, 100,100)/100
# img[42,22] = 1
# img = imfilter(img, Kernel.gaussian(3))
# p = CartesianIndex(44,27)
# p1 = image_feedback(img, p)
# imshow(img)


# # test
# tip = CartesianIndex(671, 822)
# tip = CartesianIndex(593, 226)
# tip = CartesianIndex(534, 379)
# tip = CartesianIndex(581, 639)
# # 1
tip = CartesianIndex(744, 263)

function initiate_model(Δx::Unitful.Length, Δt::Unitful.Time)
    p0 = [NaN, NaN, 0.0, 4.]
    P0 = 10*eye(4)
    A = [1.0 0.0 1.0 0.0
        0.0 1.0 0.0 1.0
        0.0 0.0 1.0 0.0
        0.0 0.0 0.0 1.0
    ]
    b = [0.0, 0.0, 0.0, 0.0]
    Q = 1*diagm([1.0, 1.0, 5.0, 5.0])
    y = [NaN, NaN]
    C = eye(2, 4)
    R = 2eye(2)
    M = LinearHomogSystem(p0, P0, A, b, Q, y, C, R)
    d2, d = Kalman.dims(M)
    LinearHomogSystem(SVector{d}(M.x0), 
    SMatrix{d,d}(M.P0),
    SMatrix{d,d}(M.Phi),
    SVector{d}(M.b),
    SMatrix{d,d}(M.Q),
    SVector{d2}(M.y),
    SMatrix{d2,d}(M.H),
    SMatrix{d2,d2}(M.R))
end

M = initiate_model(md.Δx, st.Δt)
X0 = SVector(tip.I..., M.x0[3], M.x0[4])
P0 = M.P0


sz = 1024
border = 10
inside(i::Float64) = 1 + border < i < sz - border
inside(p::Point) = all(inside.(p))

x = X0
P = P0
N = st.n-1
points = [Point(0,0) for i in 1:N]

xs = []
for t in 1:N
    img = load(st.timelapse[t].dark.path)
    x, Ppred, A = Kalman.predict!(st.timelapse[t].dark.time, x, P, st.timelapse[t+1].dark.time, M)
    y, err = image_feedback(img, CartesianIndex(round.(Int, x[1:2])...))
    _, obs, C, R = Kalman.observe!(st.timelapse[t].dark.time, x, P, st.timelapse[t+1].dark.time, y, M)
    x, P, yres, S, K = Kalman.correct!(x, Ppred, obs, C, R, M)
    push!(xs, x)
    if inside(Point(x[1:2]))
        points[t] = x[1:2]
    else
        break
    end
end






t = 1
img = load(st.timelapse[t].dark.path)
img1 = imadjustintensity(img, quantile(vec(Float64.(img)), [.1, .995]))
img = load(st.timelapse[N].dark.path)
img2 = imadjustintensity(img, quantile(vec(Float64.(img)), [.1, .995]))
imgc = map(img1, img2) do i1, i2
    x1 = Float64(i1)
    x2 = Float64(i2)
    RGB(x1, x1, x2)
end

using ImageView, ImageDraw
draw!(imgc, [ImageDraw.Point(CartesianIndex(round.(Int, p)...)) for p in points], eltype(imgc)(1,0,0))
imshow(imgc)



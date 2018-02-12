include("../src/miscsetup.jl")
include("../src/filter.jl")
include("../src/track.jl")
include("../src/model.jl")

using Base.Test

sz = (1024, 1024)
nframe = 25
@time imgs0 = zeros(sz...,  nframe)
@time for k in 1:nframe
    imgs0[:,:,k] = convert(Matrix{Float64}, Images.load(joinpath(Pkg.dir("TrackRoots"), "test", "testimage", "$k.TIF")))
end
imgs = normalize!(imgs0[1:768, :, :])
logimgs = normalize!(log.(0.003 + imgs))


tips = [((138.511, 536.277), 2.35367),
        ((257.507, 556.098), 1.82965),
        ((382.279, 428.468), 1.84742),
        ((523.581, 543.956), 1.91286),
        ((574.405, 539.448), 1.83611),
        ((693.938, 521.589), 1.82364),
        ((694.327, 356.419), 5.10786),
        ((798.665, 635.654), 2.35362),
        ((884.091, 460.284), 2.18453),
        ((948.329, 593.023), 2.55287)
]
M = Model1
ntips = length(tips)
X0 = [SVector(tips[i][1]..., M.x0[3:4]...) for i in 1:ntips]
P0 = [M.P0 for i in 1:ntips]
roots, ll = trackandfilter(tostatic(Model1), imgs, X0, P0, 10)

@test norm(roots[end][1:2] - [930.207, 692.298]) < 0.1
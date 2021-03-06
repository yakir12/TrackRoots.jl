using Kalman, Plots

import Base:+
+(p::Mark, i::CartesianIndex{2}) = p + Mark(i.I...)
+(i::CartesianIndex{2}, p::Mark) = p + i

const Image = Matrix{Gray{N0f16}}

const speed = 0.1719606156256064 # mean downwards speed along the rows of the image in mm per hour
# const ρ = (0.8, 0.5) # how much do you trust each speed. This has been calculated from a bunch of datasets
# const ρ = 0.8 # how much do you trust each speed. This has been calculated from a bunch of datasets
# const Qρ = (0.38629498696108994*(1 - ρ[1]^2), 0.2584574519006643*(1 - ρ[2]^2))
# const Qρ = 0.32*(1 - ρ^2)

const weight_disk = disk(weight_radius)
const intensity_disk = disk(intensity_radius)

function image_feedback(img::Image, p::Mark)
    ind = mark2cart(p)
    μ = mean(img[i + ind] for i in weight_disk)
    S = sum(max(0, img[i + ind] - μ) for i in weight_disk)
    sum(max(0, img[i + ind] - μ)*(i + p) for i in weight_disk)/S
end

function initiatemodel(vrow::Float64)
    p0 = SVector(NaN, NaN, vrow, 0.0)
    P0 = 10*@SMatrix eye(4)
    # A = SMatrix{4, 4, Float64}([1 0 1 0
    #                             0 1 0 1
    #                             0 0 ρ 0
    #                             0 0 0 ρ])
    A = SMatrix{4, 4, Float64}([1 0 1 0
                                0 1 0 1
                                0 0 1 0
                                0 0 0 1])
    # b = SVector(0, 0, (1-ρ)*vrow, 0)
    b = SVector(0., 0, 0, 0)
    # Q = 1*SMatrix{4,4, Float64}(diagm([1, 1, Qρ, Qρ]))
    Q = 1*SMatrix{4,4, Float64}(diagm([1, 1, 5, 5]))
    y = SVector(NaN, NaN)
    C = @SMatrix eye(2, 4)
    R = 2*@SMatrix eye(2)
    LinearHomogSystem(p0, P0, A, b, Q, y, C, R)
end

function getintensity(img::Image, p::Mark)
    ind = CartesianIndex(round.(Int, p)...)
    sum(img[i + ind] for i in intensity_disk)
end

struct Track
    lengths::Vector{Float64}
    coordinates::Vector{Mark}
    times::Vector{Float64}
    intensities::Vector{Vector{Float64}}
    id::Int
    color::RGB{Float64}
    function Track(p::Mark, st::CalibStage, id::Int, color::RGB{Float64})
        lengths = Float64[]
        coordinates = Mark[]
        times = Float64[]
        intensities = Vector{Float64}[]
        ntl = length(st.timelapse)
        sizehint!(lengths, ntl)
        sizehint!(coordinates, ntl)
        sizehint!(times, ntl)
        sizehint!(intensities, ntl)
        push!(lengths, 0.0)
        push!(coordinates, p)
        push!(times, st.timelapse[1].time)
        img = load(st.timelapse[1].path)
        I = getintensity(img, p)
        push!(intensities, [I])
        new(lengths, coordinates, times, intensities, id, color)
    end
end

function updatetrack(t::Track, img::Image, p::Mark, time::Float64)
    push!(t.lengths, t.lengths[end] + norm(t.coordinates[end] - p))
    push!(t.coordinates, p)
    push!(t.times, time)
    I = [getintensity(img, i) for i in t.coordinates]
    push!(t.intensities, I)
end


mutable struct Root
    model::LinearHomogSystem
    x::SVector{4, Float64}
    P::SMatrix{4, 4, Float64}
    grow::Bool
    function Root(p::Mark, vrow::Float64)
        model = initiatemodel(vrow)
        x = SVector(p..., model.x0[3:4]...)
        P = model.P0
        new(model, x, P, true)
    end
end

function correctpredict!(r::Root, img::Image, t1::Float64, t2::Float64)
    x, Ppred, A = Kalman.predict!(t1, r.x, r.P, t2, r.model)
    if outside(x[1:2])
        r.grow = false
        return nothing
    end
    y = image_feedback(img, Mark(x[1:2]...))
    _, obs, C, R = Kalman.observe!(t1, x, r.P, t2, y, r.model)
    x, P, yres, S, K = Kalman.correct!(x, Ppred, obs, C, R, r.model)
    if outside(r.x[1:2])
        r.grow = false
        return nothing
    end
    r.x = x
    r.P = P
    return nothing
end

function trackroot(st::CalibStage, startpoints::Vector{Mark})
    isempty(startpoints) && return Track[]
    vrow = speed/st.speed
    roots = [Root(p, vrow) for p in startpoints]
    n = length(startpoints)
    inds = 1:n
    m = 5
    C(g::ColorGradient) = RGB[g[z] for z=linspace(0,1,m)]
    colors = distinguishable_colors(n+m, C(cgrad(:inferno)))[m+1:end]
    tracks = [Track(p, st, i, c) for (i, p, c) in zip(inds, startpoints, colors)]
    for (tl1, tl2) in zip(st.timelapse[2:end], [st.timelapse[3:end]; st.timelapse[end]])
        img = load(tl1.path)
        for (r, t) in zip(roots, tracks)
            if r.grow
                correctpredict!(r, img, tl1.time, tl2.time)
                updatetrack(t, img, Mark(r.x[1:2]), tl2.time)
            end
        end
    end
    return tracks
end

# end # module

using Kalman, Unitful, FileIO, Colors, FixedPointNumbers, StaticArrays
const Image = Matrix{Gray{N0f16}}
const Point = SVector{2, Float64}
import Base:+
+(p::Point, i::CartesianIndex{2}) = p + Point(i.I...)
+(i::CartesianIndex{2}, p::Point) = p + i
# StatsBase, OffsetArrays, Colors, FixedPointNumbers, AxisArrays, IntervalSets
const speed = 4.127054775014554u"mm/d" # mean downwards speed along the rows of the image
const ρ = (0.8, 0.5) # how much do you trust each speed. This has been calculated from a bunch of datasets
const Qρ = (0.38629498696108994*(1 - ρ[1]^2), 0.2584574519006643*(1 - ρ[2]^2))
const weight_disk = disk(weight_radius)
function image_feedback(img::Image, p::Point)
    ind = CartesianIndex(round.(Int, p)...)
    μ = mean(img[i + ind] for i in weight_disk)
    S = sum(max(0, img[i + ind] - μ) for i in weight_disk)
    sum(max(0, img[i + ind] - μ)*(i + p) for i in weight_disk)/S
end
function initiatemodel(vrow::Float64)
    p0 = SVector(NaN, NaN, vrow, 0.0)
    P0 = 10*@SMatrix eye(4)
    A = SMatrix{4, 4, Float64}([1 0 1 0
                                0 1 0 1
                                0 0 ρ[1] 0
                                0 0 0 ρ[2]])
    b = SVector(0, 0, (1-ρ[1])*vrow, (1-ρ[2])*0)
    Q = 1*SMatrix{4,4, Float64}(diagm([1, 1, Qρ...]))
    y = SVector(NaN, NaN)
    C = @SMatrix eye(2, 4)
    R = 2*@SMatrix eye(2)
    LinearHomogSystem(p0, P0, A, b, Q, y, C, R)
end
const intensity_disk = disk(intensity_radius)
function getintensity(img::Image, p::Point)
    ind = CartesianIndex(round.(Int, p)...)
    sum(img[i + ind] for i in intensity_disk)
end
struct Track
    lengths::Vector{Float64}
    coordinates::Vector{Point}
    times::Vector{Float64}
    intensities::Vector{Vector{Float64}}
    index::Int
    function Track(p::Point, st::Stage, index::Int)
        lengths = Float64[]
        coordinates = Point[]
        times = Float64[]
        intensities = Vector{Float64}[]
        sizehint!(lengths, st.n)
        sizehint!(coordinates, st.n)
        sizehint!(times, st.n)
        sizehint!(intensities, st.n)
        push!(lengths, 0.0)
        push!(coordinates, p)
        push!(times, st.timelapse[1].dark.time)
        img = load(st.timelapse[1].dark.path)
        I = getintensity(img, p)
        push!(intensities, [I])
        new(lengths, coordinates, times, intensities, index)
    end
end

function updatetrack(t::Track, img::Image, p::Point, time::Float64)
    push!(t.lengths, t.lengths[end] + norm(t.coordinates[end] - p))
    push!(t.coordinates, p)
    push!(t.times, time)
    I = [getintensity(img, i) for i in t.coordinates]
    push!(t.intensities, I)
end


mutable struct Root
    model::LinearHomogSystem
    track::Track
    x::SVector{4, Float64}
    P::SMatrix{4, 4, Float64}
    grow::Bool
    function Root(p::Point, vrow::Float64, st::Stage, index::Int)
        model = initiatemodel(vrow)
        track = Track(p, st, index)
        x = SVector(p..., model.x0[3:4]...)
        P = model.P0
        new(model, track, x, P, true)
    end
end

function mypredict!(r::Root, img::Image, t1::Float64, t2::Float64)
    x, Ppred, A = Kalman.predict!(t1, r.x, r.P, t2, r.model)
    y = image_feedback(img, Point(x[1:2]...))
    _, obs, C, R = Kalman.observe!(t1, x, r.P, t2, y, r.model)
    r.x, r.P, yres, S, K = Kalman.correct!(x, Ppred, obs, C, R, r.model)
end

function mytrack(st::Stage, ps::Vector{Point})
    isempty(ps) && return Track[]
    vrow = uconvert(NoUnits, st.Δt*speed/st.Δx)
    roots = [Root(p, vrow, st, i) for (i, p) in enumerate(ps)]
    for (tl1, tl2) in zip(st.timelapse[2:end], [st.timelapse[3:end]; st.timelapse[end]])
        img = load(tl1.dark.path)
        for r in roots
            if r.grow
                mypredict!(r, img, tl1.dark.time, tl2.dark.time)
                updatetrack(r.track, img, Point(r.x[1:2]), tl2.dark.time)
                if outside(r.x[1:2])
                    r.grow = false
                end
            end
        end
    end
    return [root.track::Track for root in roots]
end



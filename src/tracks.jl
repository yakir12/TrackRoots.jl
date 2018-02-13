using StaticArrays, Kalman, StatsBase, OffsetArrays, Colors, FixedPointNumbers, Unitful, FileIO

import StatsBase:predict!

const Point = SVector{2, Float64}
const Image = Matrix{Gray{N0f16}}
const Index = CartesianIndex{2}

const speed = 4.127054775014554u"mm/d" # mean downwards speed along the rows of the image
const ρ = (0.8, 0.5) # how much do you trust each speed. This has been calculated from a bunch of datasets
const Qρ = (0.38629498696108994*(1 - ρ[1]^2), 0.2584574519006643*(1 - ρ[2]^2))

w = 3
const XY = hcat(vec(Base.vect.(Float64.(-w:w), Float64.(-w:w)'))...)
const window = CartesianRange(CartesianIndex(-w, -w), CartesianIndex(w, w))

const V = OffsetArray(Gray{N0f16}, -w:w, -w:w)
const Y = zeros((2w + 1)^2)

const sz = 1024
border = 2w
outside(i::Float64) = i ≤ 1 + border || i ≥ sz - border
outside(p::Vector{Float64}) = any(outside.(p))

function image_feedback(img::Image, ind::Index)
    for i in window
        V[i] = img[i + ind]
    end
    mu = mean(V)
    for (i,j) in zip(eachindex(Y), eachindex(V))
        Y[i] = max(V[j] - mu, 0.0) 
    end
    μ, Σ = mean_and_var(XY, Weights(Y), 2, corrected=false)
    new_p = Point(ind.I[1] + μ[1], ind.I[2] + μ[2])
    return (new_p, sqrt(sum(diag(Σ))))
end


"""
`v` is the typical velocity vector and
`0 < ρ <= 1` is a parameter regulating how strongly
the system is attracted to attain velocity `v`.
"""
function model(vrow::Float64)
    # @assert 0 < ρ ≤ 1 "ρ has to be larger than zero and less or equal to one."
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

mutable struct Root
    M::LinearHomogSystem
    x::SVector{4, Float64}
    P::SMatrix{4, 4, Float64}
    points::Vector{Point}
    grow::Bool
    l::Float64
    keep::Bool

    function Root(vrow::Float64, x::Tuple{Float64, Float64})
        M = model(vrow)
        new(M, SVector(x..., M.x0[3], M.x0[4]), M.P0, [Point(x...)], true, 0.0, true)
    end
end


function predict!(r::Root, img::Image, t1::Int, t2::Int)
    x, Ppred, A = Kalman.predict!(t1, r.x, r.P, t2, r.M)
    ind = CartesianIndex(round.(Int, x[1:2])...)
    y, err = image_feedback(img, ind)
    r.l += err
    # r.l += img[round.(Int, y)...]
    _, obs, C, R = Kalman.observe!(t1, x, r.P, t2, y, r.M)
    r.x, r.P, yres, S, K = Kalman.correct!(x, Ppred, obs, C, R, r.M)
    # r.l += Kalman.llikelihood(yres, S, r.M)
end

function weedout!(r::Root, μ)
    dyx = diff(r.points)
    l = sqrt.(sum.(abs2, dyx))
    a = dyx./l
    av = sqrt(mean(first.(a))^2 + mean(last.(a))^2)
    r.keep = av > 0.8 && r.l > μ
end


function mytrack(st::Stage, ps)
    vrow = uconvert(NoUnits, st.Δt*speed/st.Δx)
    roots = Root.(vrow, ps)
    μ = 0.0
    for (tl1, tl2, check) in zip(st.timelapse[2:end], [st.timelapse[3:end]; st.timelapse[end]], mod(i,30) == 0 for i in 1:st.n-1)
        img = load(tl1.dark.path)
        μ += mean(img)
        for r in roots
            if r.grow
                predict!(r, img, tl1.dark.time, tl2.dark.time)
                push!(r.points, r.x[1:2])
                if outside(r.x[1:2])
                    r.grow = false
                end
                # check && weedout!(r, μ)
            end
        end
        filter!(r -> r.keep, roots)
    end
    return roots
end

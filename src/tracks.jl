using StaticArrays, Kalman, StatsBase, OffsetArrays, Colors, FixedPointNumbers, Unitful, FileIO, AxisArrays, IntervalSets
import StatsBase:predict!
import Unitful:mm
const dy = u"d"
const Length = typeof(1.0mm)
const Point = SVector{2, Length}
const Image = typeof(AxisArray(rand(Gray{N0f16}, 2, 2), Axis{:row}(1mm:1mm:2mm), Axis{:col}(1mm:1mm:2mm)))
const speed = 4.127054775014554mm/dy # mean downwards speed along the rows of the image
const ρ = (0.8, 0.5) # how much do you trust each speed. This has been calculated from a bunch of datasets
const Qρ = (0.38629498696108994*(1 - ρ[1]^2)*1mm/dy, 0.2584574519006643*(1 - ρ[2]^2)*1mm/dy)
w = 0.1mm #TODO: check this value
const window = -w..w
border = 2w
outside(i::Float64, m::Length, M::Length) = i ≤ m + border || i ≥ M - border
outside(p::Vector{Float64}, m::Length, M::Length) = any(outside.(p, m, M))

function image_feedback(img::Image, p::Point)
    v = img[p[1] + window, p[2] + window]
    w = Float64.(v)
    μ = mean(w)
    w .= max.(w .- μ, 0)
    row = axisvalues(axes(v, Axis{:row}))[1]
    col = axisvalues(axes(v, Axis{:col}))[1]
    C = sum(w)
    sum(wi*Point(r, c) for (wi, r, c) in zip(w, row, col))/C
end

"""
`v` is the typical velocity vector and
`0 < ρ <= 1` is a parameter regulating how strongly
the system is attracted to attain velocity `v`.
"""
function initiatemodel()
    # @assert 0 < ρ ≤ 1 "ρ has to be larger than zero and less or equal to one."
    p0 = SVector(NaN*1mm, NaN*1mm, speed, 0.0mm/dy)
    P0 = 10*SMatrix{4,4, Unitful.Quantity{Float64,D,U} where U where D}(diagm([1mm, 1mm, 1mm/dy, 1mm/dy].^2))
    A = SMatrix{4, 4, Float64}([1 0 1 0
                                0 1 0 1
                                0 0 ρ[1] 0
                                0 0 0 ρ[2]])
    b = SVector(0mm, 0mm, (1-ρ[1])*speed, (1-ρ[2])*0mm/dy)
    Q = 1*SMatrix{4,4, Unitful.Quantity{Float64,D,U} where U where D}(diagm([1mm, 1mm, Qρ...].^2))
    y = SVector(NaN*1mm, NaN*1mm)
    C = @SMatrix eye(2, 4)
    R = 2mm^2*@SMatrix eye(2)
    LinearHomogSystem(p0, P0, A, b, Q, y, C, R)
end

function predict!(r::Root, img::Image, t1::Int, t2::Int)
    x, Ppred, A = Kalman.predict!(t1, r.x, r.P, t2, r.M)
    y = image_feedback(img, x)
    _, obs, C, R = Kalman.observe!(t1, x, r.P, t2, y, r.M)
    r.x, r.P, yres, S, K = Kalman.correct!(x, Ppred, obs, C, R, r.M)
end

Δx = 0.04mm
img = AxisArray(rand(Gray{N0f16}, 1024, 1024), Axis{:row}(Δx:Δx:1024Δx), Axis{:col}(Δx:Δx:1024Δx))
p = Point(20mm, 32mm)
t1 = 10.0dy
t2 = 12.0dy
M = initiatemodel()

x = SVector(p..., M.x0[3], M.x0[4])
P = M.P0

x, Ppred, A = Kalman.predict!(t1, x, P, t2, M)



mutable struct Root
    M::LinearHomogSystem
    x::SVector{4, Float64}
    P::SMatrix{4, 4, Float64}
    points::Vector{Point}
    grow::Bool
    # err::Float64
    # I::Float64
    # l::Float64
    # keep::Bool

    function Root(x::Point)
        M = initiatemodel()
        new(M, SVector{4, Float64}(x..., M.x0[3], M.x0[4]), M.P0, [Point(x.I...)], true, 0.0, true)
    end
end

getdisk(Δx::Unitful.Length, w = 1u"mm") = [[x,y] for x in -w:Δx:w for y in -w:Δx:w if sqrt(x^2 + y^2) ≤ w]

function get_dis_int(img::Image, p1, p2, Δx::Unitful.Length, disk)
    r1 = Δx*p1
    r2 = Δx*p2
    i = r2 - r1
    l = norm(i)
    i /= l
    Δ = min(Δx/2, l/2)
    distances = linspace(0u"mm", l, ceil(Int, max(l/Δx, 2)))[2:end]
    rs = [r1 + d*i for d in distances]
    intensities = map(rs) do r
        dr = unique(CartesianIndex(round.(Int, (d + r)/Δx)...) for d in disk)
        sum(Float64.(img[dr]))
    end
    return (distances, intensities)
end


    img = load(md.stages[1].timelapse[1].dark.path)
    p1 = [100,200]
    p2 = [109,205]
    Δx = .1u"mm"
    disk = getdisk(Δx)
fun(img, p1, p2, Δx, disk)




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
    n = 10
    for (tl1, tl2) in zip(st.timelapse[2:n], [st.timelapse[3:n]; st.timelapse[n]])#, mod(i,30) == 0 for i in 1:st.n-1)
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
        # filter!(r -> r.keep, roots)
    end
    return roots
end

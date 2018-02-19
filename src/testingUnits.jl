using Kalman, Unitful, StaticArrays, AxisArrays
import Unitful:mm
const dy = u"d"
const Length = typeof(1.0mm)
const Point = SVector{2, Length}
const speed = 4.1mm/dy
const ρ = (0.8, 0.5)
const Qρ = (0.38629498696108994*(1 - ρ[1]^2), 0.2584574519006643*(1 - ρ[2]^2))
p0 = SVector(NaN*1mm, NaN*1mm, speed, 0.0mm/dy)
P0 = 10*SMatrix{4, 4, Unitful.Quantity{Float64,D,U} where U where D}([
                                                                      1mm^2 0mm^2 0mm^2/dy 0mm^2/dy
                                                                      0mm^2 1mm^2 0mm^2/dy 0mm^2/dy
                                                                      0mm^2/dy 0mm^2/dy 1mm^2/dy^2 0mm^2/dy^2
                                                                      0mm^2/dy 0mm^2/dy 0mm^2/dy^2 1mm^2/dy^2
                                                                     ])
A = SMatrix{4, 4, Unitful.Quantity{Float64,D,U} where U where D}([
                            1 0 1dy 0dy
                            0 1 0dy 1dy
                            0/dy 0/dy ρ[1] 0
                            0/dy 0/dy 0 ρ[2]
                           ])
b = SVector(0mm, 0mm, (1-ρ[1])*speed, (1-ρ[2])*0mm/dy)
Q = 1*SMatrix{4, 4, Unitful.Quantity{Float64,D,U} where U where D}([
                                                                      1mm^2 0mm^2 0mm^2/dy 0mm^2/dy
                                                                      0mm^2 1mm^2 0mm^2/dy 0mm^2/dy
                                                                      0mm^2/dy 0mm^2/dy Qρ[1]*mm^2/dy^2 0mm^2/dy^2
                                                                      0mm^2/dy 0mm^2/dy 0mm^2/dy^2 Qρ[2]*mm^2/dy^2
                                                                     ])
y = SVector(NaN*1mm, NaN*1mm)
C = 1*SMatrix{2, 4, Unitful.Quantity{Float64,D,U} where U where D}([
                                                                      1 0 0dy 0dy
                                                                      0 1 0dy 0dy
                                                                     ])
R = 2mm^2*@SMatrix eye(2)
M = LinearHomogSystem(p0, P0, A, b, Q, y, C, R)
Δx = 0.04mm
p = Point(20mm, 32mm)
t1 = 10.0dy
t2 = 12.0dy
x = SVector(p..., M.x0[3], M.x0[4])
P = M.P0
x, Ppred, A = Kalman.predict!(t1, x, P, t2, M)
y = Point(.3mm, 6mm)
_, obs, C, R = Kalman.observe!(t1, x, P, t2, y, M)
x, P, yres, S, K = Kalman.correct!(x, Ppred, obs, C, R, M)

using StaticArrays

const Point = SVector{2, Float64}

disk(r::Int) = [CartesianIndex(y,x) for y in -r:r for x in -r:r if sqrt(y^2 + x^2) ≤ r]

const sz = 1024
const intensity_radius = 3
const weight_radius = 5
const border = max(intensity_radius, weight_radius) + 1

outside(i::Float64) = i ≤ 1 + border || i ≥ sz - border
outside(p::T) where T <: AbstractVector = any(outside(i) for i in p)

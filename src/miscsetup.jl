using Images, Kalman, GaussianDistributions

import Base.LinAlg.normalize!
function normalize!(x::AbstractArray)
    l, u = extrema(x)
    (x - l)/(u - l)
end
greyscale(A) = map(x->RGB(x,x,x), normalize!(copy(A)));
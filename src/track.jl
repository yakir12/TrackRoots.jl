# Move to Module
using StaticArrays
const Point = SVector{2,Float64}
# end


"""
Transform coordinates into pixel matrix column and row.

Todo: Boundary check
"""
ij(img, p) =  round(Int, p[2]), round(Int, p[1])

"""
Track blurry lightsource by applying a window with half-width `h` at 
an approximate location `x` and `y` and find the
average weighted location of points with *high* light intensity. 

Gives an standard error estimate.

Todo: Catch out of bounds errors.
"""
function track(img, p, h = 10)
    i, j = ij(img, p)
    CR = CartesianRange(CartesianIndex(i - h, j - h),CartesianIndex(i + h, j + h))
    μ = mean(img[ci] for ci in CR)
    C = sum(max(img[ci] - μ, 0) for ci in CR) 
    yhat = sum(max(img[ci] - μ, 0)*ci[1] for ci in CR)/C
    xhat = sum(max(img[ci] - μ, 0)*ci[2] for ci in CR)/C
    yerr =  sum(max(img[ci] - μ, 0)*(ci[1] - yhat)^2 for ci in CR)/C
    xerr =  sum(max(img[ci] - μ, 0)*(ci[2] - xhat)^2 for ci in CR)/C
    err = sqrt(xerr + yerr)
    Point(xhat, yhat), err
end
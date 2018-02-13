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


img = rand(100,100)

p = CartesianIndex(30,30)
x,y = track(img, p)

x = p[2]
y = p[1]
h = 10
XY = hcat(vec(Base.vect.(Float64.(x-h:x+h)', Float64.(y-h:y+h)))...)' 
i = [CartesianIndex(Int(XY[i,2]), Int(XY[i,1])) for i in 1:size(XY,1)]
w = img[i]
w -= mean(w)
w .= max.(w, 0)
mu, c = StatsBase.mean_and_cov(XY, StatsBase.Weights(w))
sqrt(c[1]+c[2,2])



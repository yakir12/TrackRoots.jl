using ImageFiltering, ImageFeatures, OffsetArrays, CoordinateTransformations, PaddedViews, Distances, StaticArrays, Kalman, Plots, Gtk, Images, ImageView, GtkReactive, HDF5, ProgressMeter, Interpolations
gr()
default(show=false)
const Mark = SVector{2, Float64}
const sz = 100
const intensity_radius = 2
struct Track
    coordinates::Vector{Mark}
    color::RGB{Float64}
    id::Int
end
img = rand(100,100)
formatlabel(x) = 2x+1
rs = [Track([Mark(rand(), rand()) for j in 1:100], rand(RGB{Float64}), rand(1:10)) for i in 1:5]
path = homedir()
function saveoverview(img::Matrix{Float64}, formatlabel::Function, rs::Vector{Track}, path::String)
    img .= adjust_gamma(img, 2.4)
    mM = quantile(vec(img), [.5, .995])
    img .= imadjustintensity(img, mM)
    heatmap(flipdim(img, 1), aspect_ratio = 1, yformatter = formatlabel, xformatter = formatlabel, xlabel = "X (mm)", ylabel = "Y (mm)", color=:inferno, yflip=true, colorbar=false, legend=false, size=(sz,sz), dpi=50/3)
    for r in rs
        x = last.(r.coordinates)
        y = first.(r.coordinates)
        plot!(x, y, color=r.color, linestyle = :dot, linewidth = 5, linewidth = intensity_radius, annotations=(x[1],y[1],text(string(r.id), :left, r.color, 25))) # works
    end
    png(joinpath(path, "roots"))
end
saveoverview(img, formatlabel, rs, path)





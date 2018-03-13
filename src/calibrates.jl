using ImageFiltering, ImageFeatures, OffsetArrays, CoordinateTransformations, PaddedViews #Distances

const h_kernel = Kernel.DoG((5, 180), (5*sqrt(2), 180), (31, 901))
const α = pi/2 + linspace(-.02, .02, 10)
const wavelengths = (250, 600)

exiftool_base = joinpath(Pkg.dir("TrackRoots"), "deps", "src", "exiftool", "exiftool")
const exiftool = exiftool_base*(is_windows() ? ".exe" : "")

"""
File(path, time)
A type that holds the file path and time.
"""
struct DarkFile
    path::String
    time::Float64 # in hours
end

"""
Stage(timelapse)
A type that holds all the `FilePair`s, including how many there are, `n`.
"""
struct CalibStage
    timelapse::Vector{DarkFile}
    Δt::Float64 # in hours
    Δx::Float64 # in mm
    speed::Float64 # in mm/hour
    id::Int
    home::String
    base::String

    CalibStage(timelapse::Vector{DarkFile}, Δt::Float64, Δx::Float64, id::Int, home::String, base::String) = new(timelapse, Δt, Δx, Δx/Δt, id, home, base)
end

tohour{T}(t::T) = t/convert(T, Dates.Hour(1))

"""
parse2hours(txt)
Convert `txt` to milliseconds.
"""
function parse2hours(x::String)
    m = match(r"^(\d\d\d\d)(\d\d)(\d\d) (\d\d):(\d\d):(\d\d).?(\d?\d?\d?)", x)
    @assert m ≠ nothing "Failed to extract date and time from string $x"
    tohour(DateTime(parse.(Int, m.captures)...) - DateTime(0))
end

#="""
find_vertical_distances(file)
Find all the distances between vertical edges in an image. Helps detect the grid lines in the background of the light images.
"""
function find_vertical_distances(file::String)
    img = load(file)
    I = imfilter(img, h_kernel, "symmetric")
    threshold = quantile(vec(I), 0.99)
    img_edges = I .> threshold
    lines = hough_transform_standard(img_edges, 1, α, 40, 10)
    x = first.(lines)'
    return vec(pairwise(Cityblock(), x))
end=#


sort_sum(h::Vector{Float64}) = 1/sum(sort(h, rev=true)[1:4])
rotateim(img::Matrix{Float64}, θ::Float64) = warp(img, recenter(RotMatrix(θ), Images.center(img)), 0)
collapseim(img::OffsetArray{Float64,2,Matrix{Float64}}, dim::Int) = vec(parent(sum(img, dim)))
function rotate_sum(img::Matrix{Float64}, θ::Float64)
    imgw = rotateim(img, θ)
    h = collapseim(imgw, 1)
    # v = collapseim(imgw, 2)
    sort_sum(h)# + sort_sum(v)
end
function shift_compare(v::Vector{Float64}, h::Vector{Float64}, step::Int)
    v1 = circshift(v, step)
    v1 + h
end
shift_sum(v::Vector{Float64}, h::Vector{Float64}, step::Int) = sort_sum(shift_compare(v, h, step))

function pixel_width(st::Stage)
    file1 = st.timelapse[1].light
    file2 = st.timelapse[end].light
    img1 = load(file1)
    img2 = load(file2)
    img = [(Float64(i1) + Float64(i2))/2 for (i1, i2) in zip(img1, img2)]
    _, i = findmin(rotate_sum(img, x) for x in α)
    imgw = rotateim(img, α[i])
    y = collapseim(imgw, 1)
    n = length(y)
    z = PaddedView(0, y', (1,n+1*wavelengths[2]))
    wls = wavelengths[1]:wavelengths[2]
    phs = 1:wavelengths[2]
    s = [sum(z[ph + i*wl]/n for i in 0:1) for wl in wls, ph in phs]
    _, i = findmax(s)
    iwl, iph = ind2sub(size(s), i)
    wl = wls[iwl]
    80/6/wl
end


# """
# pixel_width(stages)
# Return the first good-enough pixel width from all the images in this stack.
# """
# function pixel_width(stages::Vector{Stage})
    # for st in stages
        # x = pixel_width(st)
        # isempty(x) || return 80/6/x # in mm
        # file = st.timelapse[1].light
        # x = find_vertical_distances(file)
        # filter!(i -> 200 < i < 350, x)
        # isempty(x) || return 80/6/mean(x) # in mm
    # end
    # warn("failed to automatically calibrate the images. Assuming pixels are ~0.04 mm wide, this estimation would correspond to about 350 pixels between two grid lines (please check to make sure this estimation is not too far off)")
    # return 0.03819517804872148
# end

function stages2calib(stages::Vector{Stage}, Δx::Float64)
    nst = length(stages)
    ntl = length(first(stages).timelapse)
    files = Matrix{String}(ntl, nst)
    for j in 1:nst, i in 1:ntl
        files[i, j] = stages[j].timelapse[i].dark
    end
    ts = reshape([parse2hours(x) for x in eachline(`$exiftool -T -ModifyDate -n $files`)], ntl, nst)
    ts .-= RowVector(ts[1,:])
    Δt = mean(diff(ts, 1), 1)
    calibstages = Vector{CalibStage}(nst)
    for j in 1:nst
        dfs = Vector{DarkFile}(ntl)
        for i in 1:ntl
            dfs[i] = DarkFile(files[i,j], ts[i,j])
        end
        calibstages[j] = CalibStage(dfs, Δt[j], Δx, j, stages[j].home, stages[j].base)
    end
    return calibstages
end

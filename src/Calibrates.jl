# __precompile__()
# module Calibrates

using ImageFiltering, ImageFeatures, Unitful, Distances

# export stages2calib, CalibStage

const h_kernel = Kernel.DoG((5, 180), (5*sqrt(2), 180), (31, 901))
const α = pi/2 + linspace(-.05, .05, 10)

exiftool_base = joinpath(Pkg.dir("Calibrate"), "deps", "src", "exiftool", "exiftool")
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
    Δt::Unitful.Time
    Δx::Unitful.Length
    id::Int
    home::String
    base::String
end

tomillisecond{T}(t::T) = t/convert(T, Dates.Millisecond(1))

"""
parse2hours(txt)
Convert `txt` to milliseconds.
"""
function parse2hours(x::String)
    m = match(r"^(\d\d\d\d)(\d\d)(\d\d) (\d\d):(\d\d):(\d\d).?(\d?\d?\d?)", x)
    @assert m ≠ nothing "Failed to extract date and time from string $x"
    ms = tomillisecond(DateTime(parse.(Int, m.captures)...) - DateTime(0))
    ustrip(uconvert(u"hr", 1u"ms"*ms))
end

"""
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
end

"""
pixel_width(stages)
Return the first good-enough pixel width from all the images in this stack.
"""
function pixel_width(stages::Vector{Stage})
    for st in stages
        file = st.timelapse[1].light
        x = find_vertical_distances(file)
        filter!(i -> 200 < i < 650, x)
        isempty(x) || return 80u"mm"/6/mean(x) # in mm
    end
    warning("failed to automatically calibrate the images. Assuming pixels are ~0.04 mm wide, this estimation would correspond to about 350 pixels between two grid lines (please check to make sure this estimation is not too far off)")
    return 0.03819517804872148u"mm"
end

function stages2calib(stages::Vector{Stage})
    Δx = pixel_width(stages)
    nst = length(stages)
    ntl = length(first(stages).timelapse)
    files = Matrix{String}(ntl, nst)
    for j in 1:nst, i in 1:ntl
        files[i, j] = stages[j].timelapse[i].dark
    end
    ts = reshape([parse2hours(x) for x in eachline(`$exiftool -T -ModifyDate -n $files`)], ntl, nst)
    ts .-= RowVector(ts[1,:])
    Δt = mean(diff(ts, 1), 1)*1u"hr"
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

# end # module


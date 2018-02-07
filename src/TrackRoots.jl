module TrackRoots

#TODO: check if you really need all these packages...

using Base.Dates, Images, ImageFeatures, Unitful, Distances, UnitfulAngles, OffsetArrays, StaticArrays, StatsBase, Distributions

# export pixel_width, find_temporal_distance

fwhm = 100u"μm"
# const root_tip_σ = fwhm/2sqrt(2log(2))
# const root_area = 0.3u"mm^2"
const h_kernel = Kernel.DoG((5, 180), (5*sqrt(2), 180), (31, 901))
const α = pi/2 + linspace(-.05, .05, 10)
# const crop = (200:1024, 50:974)
# const area_cutoff = 7u"mm^2"

"""
    mylinspace(d1, d2, n)

Same as `linspace` but for dates and times.
"""
function mylinspace(d1::DateTime, d2::DateTime, n::Int)
    Δ = d2 - d1
    T = typeof(Δ)
    δ = T(round(Int, Dates.value(Δ)/(n - 1)))
    d2 = d1 + δ*(n - 1)
    return d1:δ:d2
end

"""
    FilePair(dark, light)
A type that holds the file paths for both the dark and light images
"""
struct FilePair
    dark::String
    light::String
end

"""
    Stage(timelapse)
A type that holds all the `FilePair`s, including how many there are, `n`, and the range of times each image was taken in, `times`.
"""
struct Stage
    timelapse::Vector{FilePair}
    n::Int
    times::StepRange{DateTime,Millisecond}
    function Stage(timelapse::Vector{FilePair}) 
        n = length(timelapse)
        times = mylinspace(unix2datetime(mtime(timelapse[1].dark)), unix2datetime(mtime(timelapse[end].dark)), n)
        return new(timelapse, n, times)
    end
end

"""
    MetaData(home, base, stages)
A type that holds all the `Stage`s, including the path to the folder that holds the images, `home`, the base name for the images, `base`, the number of stages, `n`, and the image pixel width in mm, `Δ`.
"""
struct Metadata
    home::String
    base::String
    stages::Vector{Stage}
    n::Int
    Δ::Float64 # in mm
    Metadata(home::String, base::String, stages::Vector{Stage}) = new(home, base, stages, length(stages), pixel_width(stages))
end

_print_stage(dostages::Bool, si::Int) = dostages ? "_s$(si)" : ""

function _print_file_name(home::String, base::String, dostages::Bool, si::Int, ti::Int)
    head = "$(base)_w"
    s = _print_stage(dostages, si)
    tail = "$(s)_t$ti.TIF"
    dark = joinpath(home, "$(head)1[None]$tail")
    light = joinpath(home, "$(head)2BF 10-$tail")
    return FilePair(dark, light)
end

"""
    nd2metadata(file)
Return a `Metadata` for an `.nd` `file`. 
"""
nd2metadata(file::String) = open(file, "r") do o
    home, f = splitdir(file)
    base, _ = splitext(f)
    l = readline(o)
    @assert r"NDInfoFile"(l) "not an `.nd` file"
    l = readline(o)
    @assert r"Description"(l) "wrong `.nd` file format"
    l = readline(o)
    m = match(r"^\"StartTime1\", (\d\d\d\d)(\d\d)(\d\d) (\d\d):(\d\d):(\d\d)$", l)
    starttime = DateTime(parse.(Int, m.captures)...)
    l = readline(o)
    @assert r"true"i(l) "no time-lapse...?" 
    l = readline(o)
    m = match(r"^\"NTimePoints\", (\d*)$", l)
    ntimelapses = parse(Int, m.captures[1])
    l = readline(o)
    dostages = r"true"i(l)
    if dostages
        l = readline(o)
        m = match(r"^\"NStagePositions\", (\d*)$", l)
        nstages = parse(Int, m.captures[1])
        for i in 1:nstages
            readline(o)
        end
    else
        nstages = 1
    end
    l = readline(o)
    @assert r"true"i(l) "I don't know yet how to deal with no waves"
    l = readline(o)
    m = match(r"^\"NWavelengths\", (\d*)$", l)
    nwaves = parse(Int, m.captures[1])
    wavenames = Vector{String}(nwaves)
    for i in 1:nwaves
        l = readline(o)
        m = match(r"^\"WaveName\d\", \"(.*)\"$", l)
        wavenames[i] = replace(m.captures[1], '%', '-')
        l = readline(o)
        if r"true"i(l)
            l = readline(o)
            @assert r"false"i(l) "I don't know yet how to deal with `ZSeries`" 
        end
    end
    l = readline(o)
    waveinfilename = r"true"i(l)
    stages = Stage[]
    for si in 1:nstages
        timelapse = FilePair[]
        for fi in 1:ntimelapses
            push!(timelapse, _print_file_name(home, base, dostages, si, fi))
        end
        push!(stages, Stage(timelapse))
    end
    return Metadata(home, base, stages)
end

#=function find_temporal_distance(md::Metadata)
    d = unix2datetime(mean(mtime(s.timelapse[end].light) - mtime(s.timelapse[1].light) for s in md.stages)) - unix2datetime(0)
    return ustrip(uconvert(u"d", Dates.value(d)*u"ms")) # in days
end=#

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
        isempty(x) || return 80/6/mean(x) # in mm
    end
    return NaN
end

#=function segment(st::TrackRoots.Stage, pixspace::Unitful.Length)
    kernel = Kernel.DoG(uconvert(Unitful.NoUnits, root_tip_σ/pixspace))
    I = imfilter(view(load(st.timelapse[1].dark), crop...), kernel)
    I .= imadjustintensity(I, quantile(vec(I), [0.9, 0.99]))
    return felzenszwalb(I, 50, round(Int, uconvert(Unitful.NoUnits, root_area/pixspace^2)))
end

function root_coordinates(segments, pixspace::Unitful.Length)
    cutoff = uconvert(Unitful.NoUnits, area_cutoff/pixspace^2)
    xy = component_boxes(labels_map(segments))
    deleteat!(xy ,1)
    p = Dict(k => Vector{CartesianIndex{2}}() for (k,v) in segment_pixel_count(segments) if v < cutoff && first(first(xy[k])) < 513 - start(first(crop)))
    lm = labels_map(segments)
    h, w = size(lm)
    for x = 1:w, y = 1:h
        i = lm[y, x]
        haskey(p, i) && push!(p[i], CartesianIndex{2}(y, x))
    end
    return p
end

function print_roots(p, name::String)
    img = Array{RGB{N0f8}}(1024, 1024)
    fill!(img, RGB(0,0,0))
    i = view(img, crop...)
    colors = distinguishable_colors(length(p) + 1, RGB(0,0,0))[2:end]
    for (v, c) in zip(values(p), colors)
        i[v] .= c
    end
    save(name, img)
end=#


end # module


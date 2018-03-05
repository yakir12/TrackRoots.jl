# __precompile__()
# module Stages

# export Stage, nd2stages

"""
FilePair(dark, light)
A type that holds the file data for both the dark and light images
"""
struct FilePair
    dark::String
    light::String
end

"""
Stage(timelapse)
A type that holds all the `FilePair`s, including how many there are, `n`.
"""
mutable struct Stage
    timelapse::Vector{FilePair}
    id::Int
    home::String
    base::String
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
nd2stages(file)
Return a `Metadata` for an `.nd` `file`. 
"""
nd2stages(file::String) = open(file, "r") do o
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
    timelapses = map(1:nstages) do si
        map(1:ntimelapses) do fi
            _print_file_name(home, base, dostages, si, fi)
        end
    end
    stages = Stage[]
    for (i, tl) in enumerate(timelapses)
        push!(stages, Stage(tl, i, home, base))
    end
    return stages
end

# end # module


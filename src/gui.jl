using ImageView, FileIO, Colors, GtkReactive, StaticArrays, Images
const PixelPoint = SVector{2, Float64}
pixelpoint(p::XY{UserUnit}) = PixelPoint(p.y.val, p.x.val)
__print_stage(dostages::Bool, si::Int) = dostages ? "_s$(si)" : ""
function __print_file_name(home::String, base::String, dostages::Bool, si::Int, ti::Int)
    head = "$(base)_w"
    s = __print_stage(dostages, si)
    tail = "$(s)_t$ti.TIF"
    return joinpath(home, "$(head)1[None]$tail")
end
startstopfiles(file::String) = open(file, "r") do o
    # o = open(ndfile, "r")
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
    return (home, base, [[__print_file_name(home, base, dostages, si, fi) for fi in [1, ntimelapses]] for si in 1:nstages])
end
function adjustimg(file::String)
    img = Float64.(load(file))
    mM = quantile(vec(img), [.1, .995])
    img .= imadjustintensity(img, mM)
end
function getroots(stage::Vector{String}, home::String, base::String)
    img = adjustimg.(stage)
    # imgc = colorview(RGB, img[2], img...)
    imgc = [RGB(i2, i1, i2) for (i1, i2) in zip(img...)]
    const g = imshow(imgc, name="<Shift>-click: add root tip, <Shift>-<ctrl>-click: remove tip, close window when done")
    const c = g["gui"]["canvas"]
    const add = Signal(XY{UserUnit}(1,1)) 
    const remove = Signal(XY{UserUnit}(1,1)) 
    const roots = foldp(push!, XY{UserUnit}[], add)
    const points = foldp([], add) do a, xy
        push!(a, ImageView.annotate!(g, AnnotationPoint(xy.x.val, xy.y.val, shape='.', size=10, color=RGB(1,0,0))))
    end
    sigstart = map(c.mouse.buttonpress) do btn
        if btn.button == 1
            if btn.modifiers == 1 #shift
                if !TrackRoots.outside(pixelpoint(btn.position)) # make sure the point is inside, reject otherwise
                    push!(add, btn.position)
                end
            elseif btn.modifiers == 5 #shift+ctrl
                push!(remove, btn.position)
            end
        end
    end
    GtkReactive.gc_preserve(g["gui"]["window"], sigstart) 
    removeidx = map(remove) do xy
        idx = Int[]
        for (i, root) in enumerate(value(roots))
            dxy = xy - root
            if sqrt(dxy.x.val^2 + dxy.y.val^2) < 50
                push!(idx, i)
            end
        end
        return idx
    end
    foreach(removeidx) do i
        deleteat!(value(roots), i)
        for j in i
            delete!(g, value(points)[j])
        end
        deleteat!(value(points), i)
    end
    close = Condition()
    # roots2 = Signal(PixelPoint[])
    signal_connect(g["gui"]["window"], :destroy) do widget
        # push!(roots2, [PixelPoint(xy.y.val, xy.x.val) for xy in value(roots)])
        notify(close)
    end
    wait(close)
    # return roots2
    return pixelpoint.(value(roots))
    #=open(joinpath(home, "$(base)_stage$(stage_number)_tips.csv"), "w") do o
        for xy in value(roots)
            println(o, xy.x.val, ",", xy.y.val)
        end
    end=#
end


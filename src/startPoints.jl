using Images, ImageView, GtkReactive

get_point(p::XY{UserUnit}) = Mark(round(p.y.val, 2), round(p.x.val, 2))

function fetch_image(file::String)
    img = load(file)
    imgtmp = deepcopy(img)
    ms = quantile(vec(img), [.1, .999])
    return (img, imgtmp, ms)
end

function build_slider(M::Float64, message::String)
    s = slider(linspace(0,1,2^16), value=1 - M)
    b = GtkBox(:h)
    push!(b, label(message), s)
    setproperty!(b, :expand, widget(s), true)
    return (s, b)
end

function get_startpoints(f1::String, f2::String)
    # build composite image
    img1, img1tmp, ms1 = fetch_image(f1)
    img2, img2tmp, ms2 = fetch_image(f2)
    imgc = colorview(RGB, img1tmp, img2tmp, img1tmp)
    # build sliders
    M = [ms1[2], ms2[2]]
    s1, b1 = build_slider(M[1], "First frame (magenta):")
    s2, b2 = build_slider(M[2], "Last frame (green):")
    # start the gui
    g = imshow(imgc, name="Shift-click to add tip, Shift-ctrl-click to remove tip, close window when done")
    w = g["gui"]["window"]
    c = g["gui"]["canvas"]
    zr = g["roi"]["zoomregion"]
    m = [ms1[1], ms2[1]]
    # connect the sliders to the gui
    foreach(s1, s2) do M1, M2
        img1tmp .= imadjustintensity(img1, (m[1], 1 - M1))
        img2tmp .= imadjustintensity(img2, (m[2], 1 - M2))
        push!(zr, value(zr).currentview)
    end
    push!(g["gui"]["vbox"], b1, b2)
    showall(w)
    # pointing 
    add = Signal(XY{UserUnit}(1,1)) 
    remove = Signal(XY{UserUnit}(1,1)) 
    roots = foldp(push!, XY{UserUnit}[], add)
    points = foldp([], add) do a, xy
        push!(a, ImageView.annotate!(g, AnnotationPoint(xy.x.val, xy.y.val, shape='.', size=10, color=RGB(0,0,1))))
    end
    sigstart = map(c.mouse.buttonpress) do btn
        if btn.button == 1 # mouse click
            if btn.modifiers & 0x01 == 0x01 #shift
                if btn.modifiers & 0x04 == 0x04 # Ctrl and Shift
                    push!(remove, btn.position)
                else
                    if !outside(get_point(btn.position)) # make sure the point is inside, reject otherwise
                        push!(add, btn.position)
                    end
                end
            end
        end
    end
    GtkReactive.gc_preserve(w, sigstart) 
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
    Gtk.signal_connect(w, :destroy) do widget
        notify(close)
    end
    wait(close)
    return get_point.(value(roots))
end

function get_startpoints(stage::Stage) 
    path = joinpath(stage.home, stage.base, "stage $(stage.id)")
    mkpath(path)
    file = joinpath(path, "start_points.csv")
    if isfile(file) 
        info("Starting points already exist for stage #$(stage.id). Using those (delete $file if you want to choose new starting points)…")
        a = readcsv(file, Float64)
        n = size(a, 1)
        return [Mark(a[i,1], a[i,2]) for i in 1:n]
    else
        for f in readdir(path)
            ff = joinpath(path, f)
            if isdir(ff)
                r"^root \d*$"(f) && rm(ff, recursive=true)
            else
                "roots.png" == f && rm(ff)
            end
        end
        startpoints = get_startpoints(stage.timelapse[1].dark, stage.timelapse[end].dark)
        isempty(startpoints) || writecsv(file, startpoints)
        return startpoints
    end
end


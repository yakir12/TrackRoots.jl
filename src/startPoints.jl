using Images, ImageView, GtkReactive

get_point(p::XY{UserUnit}) = Mark(p.y.val, p.x.val)

function get_startpoints(f1::String, fn::String)
    img1 = load(f1)
    img2 = load(fn)
    img1tmp = deepcopy(img1)
    img2tmp = deepcopy(img2)
    ms1 = quantile(vec(img1), [.1, .999])
    ms2 = quantile(vec(img2), [.1, .999])
    m = [ms1[1], ms2[1]]
    imgc = colorview(RGB, img1tmp, img2tmp, img1tmp)
    const g = imshow(imgc, name="Shift-click to add tip, Shift-ctrl-click to remove tip, close window when done")
    const c = g["gui"]["canvas"]
    const zr = g["roi"]["zoomregion"]
    s1 = slider(linspace(0,1,2^16), value=ms1[2])
    s2 = slider(linspace(0,1,2^16), value=ms2[2])
    b1 = GtkBox(:h)
    b2 = GtkBox(:h)
    push!(b1, label("First frame:"), s1)
    setproperty!(b1,:expand,widget(s1),true)
    push!(b2, label("Last frame:"), s2)
    setproperty!(b2,:expand,widget(s2),true)
    foreach(s1, s2) do M1, M2
        img1tmp .= imadjustintensity(img1, (m[1], M1))
        img2tmp .= imadjustintensity(img2, (m[2], M2))
        push!(zr, value(zr).currentview)
    end
    push!(g["gui"]["vbox"], b1, b2)
    showall(g["gui"]["window"])
    const add = Signal(XY{UserUnit}(1,1)) 
    const remove = Signal(XY{UserUnit}(1,1)) 
    const roots = foldp(push!, XY{UserUnit}[], add)
    const points = foldp([], add) do a, xy
        push!(a, ImageView.annotate!(g, AnnotationPoint(xy.x.val, xy.y.val, shape='.', size=10, color=RGB(1,0,0))))
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
    Gtk.signal_connect(g["gui"]["window"], :destroy) do widget
        notify(close)
    end
    wait(close)
    return get_point.(value(roots))
end

get_startpoints(stage::Stage) = get_startpoints(stage.timelapse[1].dark, stage.timelapse[end].dark)

using Images, ImageView, GtkReactive

get_point(p::XY{UserUnit}) = Point(p.y.val, p.x.val)

function adjustimg(file::String)
    img = Float64.(load(file))
    mM = quantile(vec(img), [.1, .995])
    img .= imadjustintensity(img, mM)
end

function get_startpoints(f1::String, fn::String)
    img1 = adjustimg(f1)
    imgn = adjustimg(fn)
    imgc = colorview(RGB, imgn, img1, imgn)
    const g = imshow(imgc, name="Shift-click to add tip, Shift-ctrl-click to remove tip, close window when done")
    const c = g["gui"]["canvas"]
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
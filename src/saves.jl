using HDF5, ProgressMeter, Interpolations
gr()
default(show=false)

const nscale = 1
# const sz2 = round(Int, sz/nscale)
const sz3 = round(Int, sz/2)

function get_parameters(track::Track, Δx::Float64)
    x = last.(track.coordinates)
    y = first.(track.coordinates)
    n = length(track.lengths)
    m = minimum(minimum(i) for i in track.intensities)
    intensities = fill(m, n, n)
    for i in 1:n, j in 1:i
        intensities[j,i] = track.intensities[i][j]
    end
    lengths = track.lengths*Δx
    times = track.times
    return (x, y, n, intensities, lengths, times, m)
end

function saveit(calibstages::Vector{CalibStage}, tss::Vector{Vector{Track}}, output::IO)
    pm = Progress(sum(length(st.timelapse)*length(ts) for (st, ts) in zip(calibstages, tss)), desc = "Saving the results", output = output)
    path = joinpath(calibstages[1].home, calibstages[1].base)
    for (st, ts) in zip(calibstages, tss)
        saveit(st, ts, path, pm)
    end
end

function filterdone!(rs::Vector{Track}, path::String)
    # isdir(path) || return rs
    fs = readdir(path)
    ffs = joinpath.(path, fs)
    summary = any(zip(ffs, fs)) do fff
        ff, f = fff
        isfile(ff) && f == "roots.png"
    end
    summary || return rs
    filter!(rs) do r
        !any(zip(ffs, fs)) do fff
            ff, f = fff
            isdir(ff) && f == "root $(r.id)" && info("Results for root #$(r.id) already exist (delete folder $ff if you want to recalculate)…") == nothing
        end
    end
end

function saveit(st::CalibStage, rs::Vector{Track}, path::String, pm::Progress)
    path = joinpath(path, "stage $(st.id)")
    mkpath(path)
    info("Stage $(st.id)")
    filterdone!(rs, path)
    isempty(rs) && return nothing
    imgs = [Float64.(load(tl.path)) for tl in st.timelapse]
    # imgs = [Float64.(imresize(load(tl.path), (sz2, sz2))) for tl in st.timelapse]
    # mM = mean(quantile(vec(img), [.1, .995]) for img in imgs)
    # for img in imgs
        # img .= imadjustintensity(img, mM)
    # end
    formatlabel(x::T) where T <: Real = round(st.Δx*x*nscale, 1)
    saveoverview(deepcopy(imgs[end]), formatlabel, rs, path)
    for r in rs
        nodes = detect_nodes(r)
        # println(nodes)
        x, y, n, intensities, lengths, times, Imin = get_parameters(r, st.Δx)
        _path = joinpath(path, "root $(r.id)")
        mkpath(_path)
        save2csv(_path, x, y, intensities, lengths, times, nodes)
        save2gif(_path, nodes, x/nscale, y/nscale, n, intensities, lengths, times, formatlabel, imgs, st.Δt, Imin, pm)
    end
end

function saveoverview(img::Matrix{Float64}, formatlabel::Function, rs::Vector{Track}, path::String)
    img .= adjust_gamma(img, 2.4)
    mM = quantile(vec(img), [.5, .995])
    img .= imadjustintensity(img, mM)
    heatmap(flipdim(img, 1), aspect_ratio = 1, yformatter = formatlabel, xformatter = formatlabel, xlabel = "X (mm)", ylabel = "Y (mm)", color=:inferno, yflip=true, colorbar=false, legend=false, dpi=50/3) # size=(sz,sz) =====>> segmentation
  # heatmap(flipdim(img, 1), aspect_ratio = 1, yformatter = formatlabel, xformatter = formatlabel, xlabel = "X (mm)", ylabel = "Y (mm)", color=:inferno, yflip=true, colorbar=false, legend=false, size=(sz,sz), dpi=50/3)
    for r in rs
        x = last.(r.coordinates)
        y = first.(r.coordinates)
        # plot!(rand(5))
        plot!(x, y, color=r.color, linestyle = :dot, linewidth = 5, linewidth = intensity_radius, annotations=(x[1],y[1],text(string(r.id), :left, r.color, 25))) # works
    end
    png(joinpath(path, "roots"))
end


function save2csv(path::String, x, y, intensities, lengths, times, nodes)
    z = [[nothing; lengths] [RowVector(times); intensities]]
    writecsv(joinpath(path, "intensities.csv"), z)
    writecsv(joinpath(path, "coordinates.csv"), zip(x, y))
    writecsv(joinpath(path, "nodes.csv"), [[lengths[node.length_i], times[node.time_i], node.Δ, node.p] for node in nodes])
end

#=function save2gif(path::String, x, y, n::Int, intensities, lengths, times, imgs, Δt::Float64, pm::Progress)
    _imgs = deepcopy(imgs)
    p = [(round(Int, xi), round(Int, yi)) for (xi, yi) in zip(x, y)]
    for i in 1:n
        draw!(_imgs[i], Path(p[1:i]), RGB{N0f16}(1,0,0))
        next!(pm)
    end
    save(joinpath(path, "root.gif"), cat(3, _imgs...), fps = round(Int, 1/(5/180000*60*60*Δt)))
    Imax = quantile(vec(intensities), 0.98)
    intensities .= min.(intensities, Imax)
    heatmap(times, lengths, intensities, xlabel = "Time (hrs)", ylabel = "Root length (mm)", yflip = true, colorbar = false)
    png(joinpath(path, "intensities.png"))
end=#

function save2gif(path::String, nodes, x, y, n::Int, intensities, lengths, times, formatlabel::Function, imgs, Δt::Float64, Imin::Float64, pm::Progress)
    Imax = quantile(vec(intensities), 0.95)
    intensities .= min.(intensities, Imax)
    xlim = round.(Int, extrema(x)) .+ [-10, 10]
    clamp!(xlim, 1, sz) 
    ylim = round.(Int, extrema(y)) .+ [-10, 10]
    clamp!(ylim, 1, sz) 
    imgs2 = [adjust_gamma(img[ylim[1]:ylim[2], xlim[1]:xlim[2]], 2.4) for img in imgs]
    mM = mean(quantile(vec(img), [.5, .99]) for img in imgs2)
    for img in imgs2
        img .= imadjustintensity(img, mM)
    end
    itp = interpolate((times, lengths), log.(intensities), Gridded(Linear()))
    xl = linspace(extrema(times)..., n)
    yl = linspace(extrema(lengths)..., n)
    zl = itp[xl, yl]
    Ibounds = extrema(zl)
    anim = Animation()
    for i in 1:n
        # h1 = heatmap(flipdim(imgs2[i],1), aspect_ratio = 1, yformatter = formatlabel, xlabel = "X (mm)", ylabel = "Y (mm)", color=:inferno, yflip=false, colorbar=false, xticks=[])
        h1 = heatmap(flipdim(imgs2[i], 1), aspect_ratio = 1, yformatter = formatlabel, xlabel = "X (mm)", ylabel = "Y (mm)", color=:inferno, yflip=true, colorbar=false, xticks=[])
        # h1 = heatmap(imadjustintensity(adjust_gamma(imgs[i], 2.4), mM), aspect_ratio = 1, color=:inferno, yflip=false, colorbar=false)
        foreach(nodes) do node
            Plots.annotate!(h1, x[node.length_i] - xlim[1], y[node.length_i] - ylim[1], text(string(round(node.Δ, 2), "-", round(node.p, 2)), RGBA(0,1,0, Int(i > node.time_i)), 8))
            # Plots.annotate!(h1, x[node.length_i] - xlim[1], y[node.length_i] - ylim[1], node.label(i))
            # Plots.scatter!(h1, [x[node.length_i] - xlim[1]], [y[node.length_i] - ylim[1]])
            # Plots.annotate!(h1, x[node.length_i], y[node.length_i], node.label(i))
            # Plots.scatter!(h1, [x[node.length_i]], [y[node.length_i]])
        end
        # plot!(x[1:i]-xlim[1], y[1:i]-ylim[1], color = :white)
        h3 = plot(xl, zl[i, :], fill = Ibounds[1], fillcolor = :blue, linecolor = :blue, ylim = Ibounds, xlim=extrema(xl), yticks = nothing, ylabel = "Intensity")
        h2 = plot([Ibounds[1]; zl[:,i]; Ibounds[1]], [yl[1]; yl; yl[end]], fill = Ibounds[1], fillcolor = :green, linecolor = :green, xlim = Ibounds, ylim=extrema(yl), xticks = nothing,  yflip = true, xlabel = "Intensity")
        h4 = heatmap(xl, yl, flipdim(zl,1), xlabel = "Time (hrs)", ylabel = "Root length (mm)", yflip = true, colorbar = false, color=:inferno)
        plot!(h4, xl[[1, end]], [yl[i], yl[i]], color = :blue)
        plot!(h4, [xl[i], xl[i]], yl[[1, end]], color = :green)
        foreach(nodes) do node
            # Plots.annotate!(h4, times[node.time_i], lengths[node.length_i], node.label(i))
        end
        plot(h3, h1, h4, h2, legend = false, size=(sz3, sz3), dpi=50/3)#, background_color=:black)
        Plots.frame(anim)
        next!(pm)
    end
    # mp4(anim, joinpath(path, "summary.mp4"), fps = round(Int, 24/10Δt))
    # for when the latest Plots get tagged:
    mp4(anim, joinpath(path, "summary.mp4"), fps = round(Int, 24/10Δt), show_msg=false)
end


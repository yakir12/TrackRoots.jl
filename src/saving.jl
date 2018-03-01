using Plots, HDF5, Images, ProgressMeter
const nscale = 4
const sz2 = round(Int, sz/nscale)
const sz3 = round(Int, 2sz2)
gr()
# default(size=(256,256)) #Plot canvas size
# default(dpi=50/3) #Only for PyPlot - presently broken
function get_parameters(r::Track, Δx::Unitful.Length)
    x = last.(r.coordinates)/4
    y = first.(r.coordinates)/4
    n = length(r.lengths)
    I = zeros(n, n)
    m = minimum(minimum(i) for i in r.intensities)
    for i in 1:n, j in 1:i
        I[j,i] = r.intensities[i][j] - m
    end
    lengths = ustrip.(r.lengths*Δx)
    times = ustrip.(uconvert.(u"hr", (r.times - r.times[1])*u"ms"))
    return (x, y, n, I, lengths, times)
end
save2hdf5(home, base, x, y, I, lengths, times, stage_number, root_number) = h5open(joinpath(home, "$(base)_stage_$(stage_number)_root_$(root_number)_summary.h5"), "w") do file
    gmain = g_create(file, "home")
    ginfo = g_create(gmain, "information")
    ginfo["base"] = base
    ginfo["home"] = home
    ginfo["stage"] = stage_number
    ginfo["root"] = root_number
    attrs(ginfo)["Description"] = "Background information about this root"
    gt = g_create(gmain, "times")
    gt["data"] = times
    attrs(gt)["Description"] = "The times in hours, corresponds to each column in the intensity matrix"
    gl = g_create(gmain, "lengths")
    gl["data"] = lengths
    attrs(gl)["Description"] = "The lengths in millimeters, corresponds to each row in the intensity matrix"
    gi = g_create(gmain, "intensities")
    gi["data"] = I
    attrs(gi)["Description"] = "The intensities in relative units. Each row is a single root length, growing from the top to the bottom. Each column is a single point in time, progressing from the top to bottom"
    gxy = g_create(gmain, "coordinates")
    gxy["data"] = [x y]
    attrs(gxy)["Description"] = "The [x y] coordinates in millimeters of the tip of the root as it moves through time."
end

function saveit(home::String, base::String, pm::Progress, st::Stage, rs::Vector{Track})
    isempty(rs) && return nothing
    imgs = [RGB.(imresize(load(tl.dark.path), (sz2, sz2))) for tl in st.timelapse]
    mM = mean(quantile(vec(green.(img)), [.1, .995]) for img in imgs)
    for img in imgs
        img .= imadjustintensity(img, mM)
    end
    formatlabel(x::T) where T <: Real = round(ustrip(st.Δx*x*nscale), 1)
    for r in rs
        x, y, n, I, lengths, times  = get_parameters(r, st.Δx)
        save2hdf5(home, base, x, y, I, lengths, times, st.index, r.index)
        save2gif(home, base, x, y, n, I, lengths, times, formatlabel, imgs, st.index, r.index, pm)
    end
end

function save2gif(home, base, x, y, n, I, lengths, times, formatlabel, imgs, stage_number, root_number, pm::Progress)
    Imax = maximum(I)
    filename = "$(base)_stage_$(stage_number)_root_$(root_number)_summary.mp4"
    anim = Animation()
    for i in 1:n
        h1 = plot(imgs[i], aspect_ratio = 1, xformatter = formatlabel, yformatter = formatlabel, xlabel = "X (mm)", ylabel = "Y (mm)")
        plot!(x[1:i], y[1:i])
        h2 = plot([I[:,i]; 0], [lengths; lengths[end]], fill = 0, fillcolor = :green, linecolor = :green, xlim = (0, Imax), xticks = nothing,  yflip = true, xlabel = "Intensity")
        h3 = plot(times, I[i, :], fill = 0, fillcolor = :blue, linecolor = :blue, ylim = (0, Imax), yticks = nothing, ylabel = "Intensity")
        h4 = heatmap(times, lengths, I, xlabel = "Time (hrs)", ylabel = "Root length (mm)", yflip = true, colorbar = false)
        plot!(times[[1, end]], [lengths[i], lengths[i]], color = :blue)
        plot!([times[i], times[i]], lengths[[1, end]], color = :green)
        plot(h3, h1, h4, h2, legend = false, size=(sz3, sz3), dpi=50/3)
        Plots.frame(anim)
        next!(pm)
    end
    mp4(anim, joinpath(home, filename), fps = 30)
end

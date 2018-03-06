using HDF5, ProgressMeter, Plots
gr()
default(show=false)

const nscale = 2
const sz2 = round(Int, sz/nscale)
const sz3 = round(Int, 2sz2)

function get_parameters(track::Track, Δx::Float64)
    x = last.(track.coordinates)
    y = first.(track.coordinates)
    n = length(track.lengths)
    intensities = zeros(n, n)
    m = minimum(minimum(i) for i in track.intensities)
    for i in 1:n, j in 1:i
        intensities[j,i] = track.intensities[i][j] - m
    end
    lengths = track.lengths*Δx
    times = track.times
    return (x, y, n, intensities, lengths, times)
end

function saveit(calibstages::Vector{CalibStage}, tss::Vector{Vector{Track}})
    pm = Progress(sum(length(st.timelapse)*length(ts) for (st, ts) in zip(calibstages, tss)), 1, "Saving the gif files")
    for (st, ts) in zip(calibstages, tss)
        saveit(st, ts, pm)
    end
end

function saveit(st::CalibStage, rs::Vector{Track}, pm::Progress = Progress(1))
    isempty(rs) && return nothing
    imgs = [RGB.(imresize(load(tl.path), (sz2, sz2))) for tl in st.timelapse]
    mM = mean(quantile(vec(green.(img)), [.1, .995]) for img in imgs)
    for img in imgs
        img .= imadjustintensity(img, mM)
    end
    formatlabel(x::T) where T <: Real = round(st.Δx*x*nscale, 1)
    for r in rs
        x, y, n, intensities, lengths, times = get_parameters(r, st.Δx)
        save2hdf5(st.home, st.base, st.id, r.id, x, y, intensities, lengths, times)
        save2gif(st.home, st.base, st.id, r.id, x/nscale, y/nscale, n, intensities, lengths, times, formatlabel, imgs, pm)
    end
end

function save2hdf5(home::String, base::String, stage_number::Int, root_number::Int, x, y, intensities, lengths, times)
    h5open(joinpath(home, "$(base)_stage_$(stage_number)_root_$(root_number)_summary.h5"), "w") do file
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
        gi["data"] = intensities
        attrs(gi)["Description"] = "The intensities in relative units. Each row is a single root length, growing from the top to the bottom. Each column is a single point in time, progressing from the top to bottom"
        gxy = g_create(gmain, "coordinates")
        gxy["data"] = [x y]
        attrs(gxy)["Description"] = "The [x y] coordinates in millimeters of the tip of the root as it moves through time."
    end
end

function save2gif(home::String, base::String, stage_number::Int, root_number::Int, x, y, n::Int, intensities, lengths, times, formatlabel::Function, imgs, pm::Progress)
    Imax = maximum(intensities)
    anim = Animation()
    for i in 1:n
        h1 = plot(imgs[i], aspect_ratio = 1, xformatter = formatlabel, yformatter = formatlabel, xlabel = "X (mm)", ylabel = "Y (mm)")
        plot!(x[1:i], y[1:i], color = :red, linewidth = 10/nscale)
        h2 = plot([intensities[:,i]; 0], [lengths; lengths[end]], fill = 0, fillcolor = :green, linecolor = :green, xlim = (0, Imax), xticks = nothing,  yflip = true, xlabel = "Intensity")
        h3 = plot(times, intensities[i, :], fill = 0, fillcolor = :blue, linecolor = :blue, ylim = (0, Imax), yticks = nothing, ylabel = "Intensity")
        h4 = heatmap(times, lengths, intensities, xlabel = "Time (hrs)", ylabel = "Root length (mm)", yflip = true, colorbar = false)
        plot!(times[[1, end]], [lengths[i], lengths[i]], color = :blue)
        plot!([times[i], times[i]], lengths[[1, end]], color = :green)
        plot(h3, h1, h4, h2, legend = false, size=(sz3, sz3), dpi=50/3)
        Plots.frame(anim)
        next!(pm)
    end
    filename = "$(base)_stage_$(stage_number)_root_$(root_number)_summary.mp4"
    mp4(anim, joinpath(home, filename), fps = round(Int, n/5))
end

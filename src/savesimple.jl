using HDF5, ProgressMeter, ImageDraw, Plots
gr()
default(show=false)

const nscale = 4
const sz2 = round(Int, sz/nscale)
const sz3 = round(Int, 2sz2)

function get_parameters(track::Track, Δx::Float64)
    x = last.(track.coordinates)
    y = first.(track.coordinates)
    n = length(track.lengths)
    m = minimum(minimum(i) for i in track.intensities)
    intensities = zeros(n, n)
    for i in 1:n, j in 1:i
        intensities[j,i] = track.intensities[i][j] - m
    end
    lengths = track.lengths*Δx
    times = track.times
    return (x, y, n, intensities, lengths, times)
end

function saveit(calibstages::Vector{CalibStage}, tss::Vector{Vector{Track}})
    pm = Progress(sum(length(st.timelapse)*length(ts) for (st, ts) in zip(calibstages, tss)), 1, "Saving the results")
    for (st, ts) in zip(calibstages, tss)
        saveit(st, ts, pm)
    end
end

function saveit(st::CalibStage, rs::Vector{Track}, pm::Progress)
    isempty(rs) && return nothing
    imgs = [RGB.(imresize(load(tl.path), (sz2, sz2))) for tl in st.timelapse]
    mM = mean(quantile(vec(green.(img)), [.1, .995]) for img in imgs)
    for img in imgs
        img .= imadjustintensity(img, mM)
    end
    for r in rs
        x, y, n, intensities, lengths, times = get_parameters(r, st.Δx)
        save2hdf5(st.home, st.base, st.id, r.id, x, y, intensities, lengths, times)
        save2gif(st.home, st.base, st.id, r.id, x/nscale, y/nscale, n, intensities, lengths, times, imgs, st.Δt, pm)
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

function save2gif(home::String, base::String, stage_number::Int, root_number::Int, x, y, n::Int, intensities, lengths, times, imgs, Δt::Float64, pm::Progress)
    _imgs = deepcopy(imgs)
    p = [(round(Int, xi), round(Int, yi)) for (xi, yi) in zip(x, y)]
    for i in 1:n
        draw!(_imgs[i], Path(p[1:i]), RGB{N0f16}(1,0,0))
        next!(pm)
    end
    filename = "$(base)_stage_$(stage_number)_root_$(root_number)_root.gif"
    save(joinpath(home, filename), cat(3, _imgs...), fps = round(Int, 1/(5/180000*60*60*Δt)))
    Imax = quantile(vec(intensities), 0.98)
    intensities .= min.(intensities, Imax)
    heatmap(times, lengths, intensities, xlabel = "Time (hrs)", ylabel = "Root length (mm)", yflip = true, colorbar = false)
    filename = "$(base)_stage_$(stage_number)_root_$(root_number)_intensities"
    png(joinpath(home, filename))
end


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
    mkpath(joinpath(calibstages[1].home, calibstages[1].base))
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
    mkpath(joinpath(st.home, st.base, "stage $(st.id)"))
    for r in rs
        x, y, n, intensities, lengths, times = get_parameters(r, st.Δx)
        path = joinpath(st.home, st.base, "stage $(st.id)", "root $(r.id)")
        mkpath(path)
        save2csv(path, x, y, intensities, lengths, times)
        save2gif(path, x/nscale, y/nscale, n, intensities, lengths, times, imgs, st.Δt, pm)
    end
end

function save2csv(path::String, x, y, intensities, lengths, times)
    z = [[nothing; lengths] [RowVector(times); intensities]]
    writecsv(joinpath(path, "intensities.csv"), z)
    writecsv(joinpath(path, "coordinates.csv"), zip(x, y))
end

function save2gif(path::String, x, y, n::Int, intensities, lengths, times, imgs, Δt::Float64, pm::Progress)
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
end


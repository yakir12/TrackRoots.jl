using Images, ImageFiltering
#=using Plots
const w = 5
function clean_rows(x::Matrix{Float64})
    n = size(x, 1)
    map(1:n - w) do i
        j = i + w
        x[i, j:end]
    end
end
const kernel = Kernel.gaussian((0,1))
function find_peaks(μ::Vector{Float64})
    img = centered(μ')
    s = vec(parent(imfilter(img, kernel)))
    findlocalmaxima(s, 1, false)
end
function get_parameters(row::Vector{Float64}) 
    m, M = extrema(row)
    m == M && return (0.0, 0.0, 0)
    Δ = M - m
    p = (row[end] - m)/Δ
    return (Δ, p, findfirst(row .> m + Δ/2))
end
function detect_nodes(file::String)
    a = readcsv(file)
    x = Matrix{Float64}(a[2:end, 2:end])
    lengths = Float64.(a[2:end, 1])
    times = Float64.(a[1, 2:end])
    rows = clean_rows(x)
    μ = mean.(rows)
    j = find_peaks(μ)
    map(j) do i
        Δ, p, ti = get_parameters(rows[i])
        ti += i[1] + w
        t = times[ti]
        l = lengths[i]
        (l, t, Δ, p)
    end
end

file = "/home/yakir/.julia/datadeps/all/9/pos1,3-dr5_pos2,4-cle44-luc-1-5/stage 2/root 1/intensities.csv"
p = detect_nodes(file)=#

#=struct Node{T <: Function}
    length_i::Int
    time_i::Int
    label::T
end=#

struct Node
    length_i::Int
    time_i::Int
    Δ::Float64
    p::Float64
end

const kernel = Kernel.gaussian((0,0.8))
function find_peaks(μ::Vector{Float64})
    img = centered(μ')
    s = vec(parent(imfilter(img, kernel)))
    findlocalmaxima(s, 1, false)
end
function get_parameters(row::Vector{Float64}) 
    m, M = extrema(row)
    m == M && return (0.0, 0.0, 0)
    Δ = M - m
    p = (row[end] - m)/Δ
    return (Δ, p, findfirst(row .> m + Δ/2))
end
const w = 10
function detect_nodes(track::Track)
    # track = tracks[2][1]
    n = length(track.intensities)
    m = minimum(minimum(i) for i in track.intensities)
    intensities = fill(m, n, n)
    for i in 1:n, j in 1:i-w
        intensities[j,i] = track.intensities[i][j]
    end
    y = vec(mean(intensities, 2))
    j = find_peaks(y)
    map(j) do i
        Δ, p, ti = get_parameters(intensities[i, :])
        # Node(i[1], ti, x -> text("($Δ, $p)", 5, RGB(1,1,1)))
        # Node(i[1], ti, x -> text("$Δ-$p", RGBA(0,1,0, Int(x > ti)), 8))
        Node(i[1], ti, Δ, p)
    end
    #=rows = [track.intensities[i][1:end-w] for i in w + 1:n]
    y = [mean(rows[i][min(j, i)] for i in 1:n-w) for j in 1:n-w]

    # μ = mean.(rows)
    j = find_peaks(y)

    map(j) do i
        Δ, p, ti = get_parameters(rows[i])
        li = i[1] + w - 1
        ti += li
        Node(li, ti, x -> text("($Δ, $p)", 5, RGB(1,1,1)))
        # Node(li, ti, x -> text("($Δ, $p)", RGBA(1,1,1, Int(x > li)), 8))
    end=#
end



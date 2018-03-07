include(joinpath(Pkg.dir("TrackRoots"), "src", "utils.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "stages.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "startPoints.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "calibrates.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "saves.jl"))

using DataDeps
ENV["DATADEPS_ALWAY_ACCEPT"]=true
RegisterDataDep("all",
                "These are all 8 folders with their `nd` files and multiple dark and light timelapse 16 bit TIF images (7.8 GB total).",
                "https://s3.eu-central-1.amazonaws.com/yakirgagnon/roots/eight_folders.zip",
                "c316452c19e3c639737821581d18e45654980e04e0244f3d43e30d47d3e81f11",
                post_fetch_method=unpack)


startpoints = map(1:8) do dataset
    files = readdir(joinpath(datadep"all", string(dataset)))
    i = findfirst(x -> last(splitext(x)) == ".nd", files)
    ndfile = joinpath(datadep"all", string(dataset), files[i])
    stages = nd2stages(ndfile)
    get_startpoints.(stages)
end


showfull(io, x) = show(IOContext(io; compact = false, limit = false), x)
showfull(x) = showfull(STDOUT, x)

startpoints = Array{Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1},1}[Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[774.3011654713115, 911.7642161885246]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[534.2970350922132, 378.69399574154716]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[726.5627041175717, 437.72684385873276]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[470.9424388447746, 523.4365954789959]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[372.28236264088116, 549.768298539959]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[438.7849781474129, 278.5611512231045]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[544.1841620773565, 523.4520763960041]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[538.4051933913935, 509.97839191531347]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[622.5830918609118, 246.14959616739242]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[610.663294057377, 398.3634653560451]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[761.334080430328, 413.93003970286884]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[811.9541095671107, 510.3906089907787]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[527.7699234759222, 344.6583472079918]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[773.229998479124, 565.6303750635162]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[551.95458984375, 567.2299244364754]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[922.8385229892418, 487.0387503201844]], StaticArrays.SArray{Tuple{2},Float64,1,2}[], StaticArrays.SArray{Tuple{2},Float64,1,2}[[839.9598168545082, 676.9329673830143]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[401.7507044057377, 434.2714283427254]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[], StaticArrays.SArray{Tuple{2},Float64,1,2}[], StaticArrays.SArray{Tuple{2},Float64,1,2}[[701.4121974257172, 603.8230660860656]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[655.2376889088115, 595.7405865778688]]]]



endpoints = map(1:8) do dataset
    files = readdir(joinpath(datadep"all", string(dataset)))
    i = findfirst(x -> last(splitext(x)) == ".nd", files)
    ndfile = joinpath(datadep"all", string(dataset), files[i])
    stages = nd2stages(ndfile)
    calibstages = stages2calib(stages)
    tracks = trackroot.(calibstages, startpoints[dataset])
    # saveit(calibstages, tracks)
    map(tracks) do t
        map(t) do r
            r.coordinates[end]
        end
    end
end


endpoints = Array{Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1},1}[Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[904.9364522125379, 919.0443242002601]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[759.7339585464049, 349.67100009834166]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[1000.7755448226577, 469.9146794776227]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[514.1614073576073, 536.7196266118772]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[407.55891865815, 546.7966992882476]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[474.35621036315683, 278.8619310200936]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[621.3929471402455, 525.7630664775759]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[630.1256138547242, 533.5702963300903]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[688.7103937141497, 250.73057010728078]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[731.2364672532566, 380.72190178371096]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[1017.0597835688507, 208.98726714885305]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[1017.5227104153928, 315.23929042231043]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[730.2535639964862, 327.895086031576]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[1016.0545626838322, 551.2542723648528]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[945.5572309663199, 590.5367953365943]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[[1018.1700183076565, 471.4396372953533]], StaticArrays.SArray{Tuple{2},Float64,1,2}[], StaticArrays.SArray{Tuple{2},Float64,1,2}[[1017.8463747258998, 644.4757666777125]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[572.0582086956706, 423.6265374344757]]], Array{StaticArrays.SArray{Tuple{2},Float64,1,2},1}[StaticArrays.SArray{Tuple{2},Float64,1,2}[], StaticArrays.SArray{Tuple{2},Float64,1,2}[], StaticArrays.SArray{Tuple{2},Float64,1,2}[[920.6710051005372, 506.12034261277336]], StaticArrays.SArray{Tuple{2},Float64,1,2}[[774.1214888186025, 421.7462369106153]]]]


using Base.Test
for dataset in 1:8
    files = readdir(joinpath(datadep"all", string(dataset)))
    i = findfirst(x -> last(splitext(x)) == ".nd", files)
    ndfile = joinpath(datadep"all", string(dataset), files[i])
    stages = nd2stages(ndfile)
    calibstages = stages2calib(stages)
    tracks = trackroot.(calibstages, startpoints[dataset])
    @test endpoints[dataset] == map(tracks) do t
        map(t) do r
            r.coordinates[end]
        end
    end
end


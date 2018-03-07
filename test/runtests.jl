ENV["PLOTS_TEST"] = "true"
ENV["GKSwstype"] = "100"
using TrackRoots
import TrackRoots:Point
using Base.Test

using DataDeps
ENV["DATADEPS_ALWAY_ACCEPT"]=true
RegisterDataDep("test",
                "These are two folders with their `nd` files and multiple dark and light timelapse 16 bit TIF images (1.9 GB total).",
                "https://s3.eu-central-1.amazonaws.com/yakirgagnon/roots/test.zip",
                "d99b8f2edce5e72104ba1cfed02798a6683bc22f4b76a5cb823c80257bc4bf48",
                post_fetch_method=unpack)

@testset "utils" begin
    a = TrackRoots.disk(1)
    @test all(CartesianIndex(i) ∈ a for i in [(-1,0), (0,-1), (0,0), (0,1), (1,0)])
end

@testset "all" begin
    startpoints = [[Point[[774.3011654713115, 911.7642161885246]]], [Point[[761.334080430328, 413.93003970286884]], Point[[811.9541095671107, 510.3906089907787]]]]
    endpoints = [[Point[[904.9364522125379, 919.0443242002601]]], [Point[[1017.0597835688507, 208.98726714885305]], Point[[1017.5227104153928, 315.23929042231043]]]]
    for (i, dataset) in enumerate(["1","5"])
        files = readdir(joinpath(datadep"test", dataset))
        ind = findfirst(x -> last(splitext(x)) == ".nd", files)
        ndfile = joinpath(datadep"test", dataset, files[ind])
        stages = TrackRoots.nd2stages(ndfile)
        calibstages = TrackRoots.stages2calib(stages)
        tracks = TrackRoots.trackroot.(calibstages, startpoints[i])
        endpoint = map(tracks) do t
            map(t) do r
                r.coordinates[end]
            end
        end
        @test endpoints[i] == endpoint
    end
end

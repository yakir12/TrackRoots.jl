using TrackRoots
using Base.Test
using DataDeps
ENV["DATADEPS_ALWAY_ACCEPT"]=true
RegisterDataDep(
                "test",
                "These are test data including an `nd` file and multiple dark and light timelapse 16 bit TIF images (1.6 GB total).",
                "https://s3.eu-central-1.amazonaws.com/yakirgagnon/roots/test.zip",
                "ec5ea50ffcecf5875c34f9a234fc5a5c71cd34b1c838b2eacd2b695853ddb253",
                post_fetch_method=unpack
               )
files = readdir(datadep"test")
i = findfirst(x -> last(splitext(x)) == ".nd", files)
ndfile = joinpath(datadep"test", files[i])
import TrackRoots:Point
startpoints = [[Point(649, 993), Point(618, 919)], Point[]]
endpoints = [[Point(668.2858383593972, 988.693544734596), Point(642.4134353114358, 933.5568063214348)], Point[]]


@testset "all" begin

    stages = TrackRoots.nd2stages(ndfile)
    @test stages[1].id == 1
    @test string(stages[1].base, ".nd") == files[1]

    # startpoints = TrackRoots.get_startpoints.(stages)

    calibstages = TrackRoots.stages2calib(stages)
    @test calibstages[1].Δt == 0.24970093565551857
    @test calibstages[1].Δx == 0.03445036016285625

    tracks = TrackRoots.trackroot.(calibstages, startpoints)
    @test tracks[1][1].id == 1
    @test tracks[1][1].lengths[1] == tracks[1][1].times[1]

    # TrackRoots.saveit(calibstages, tracks)
    # @test isfile(joinpath(stages[1].home, "$(stages[1].base)_stage_1_root_1_summary.h5"))
    # @test isfile(joinpath(stages[1].home, "$(stages[1].base)_stage_1_root_1_summary.mp4"))

end

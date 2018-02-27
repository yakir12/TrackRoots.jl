using TrackRoots, StaticArrays
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

const Point = SVector{2, Float64}
tips = [Point(649, 993), Point(618, 919)]
ends = [Point(668.2858383593972, 988.693544734596), Point(642.4134353114358, 933.5568063214348)]

md = 0
rs = 0

@testset "basic" begin
    home, base, files = TrackRoots.startstopfiles(ndfile)
    @test home == datadep"test"[1:end-1]
    @test base == "204"
    @test files == [joinpath.(datadep"test", ["204_w1[None]_s1_t1.TIF", "204_w1[None]_s1_t20.TIF"])]
end

@testset "ndfile" begin
    md = TrackRoots.nd2metadata(ndfile)
    @test md.n == 1 
end

@testset "track" begin
    rs = TrackRoots.mytrack(md.stages[1], tips)

    @test all(c1.coordinates[1] == c2 for (c1, c2) in zip(rs, tips))
    @test all(c1.coordinates[end] == c2 for (c1, c2) in zip(rs, ends))
end

@testset "save" begin
    # save and plot
    TrackRoots.saveit(md.home, md.base, md.stages[1], rs[1:1])
    @test isfile(joinpath(md.home, "$(md.base)_stage_1_root_1_summary.h5"))
    @test isfile(joinpath(md.home, "$(md.base)_stage_1_root_1_summary.gif"))
end




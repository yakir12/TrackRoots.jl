using TrackRoots
using Base.Test
using DataDeps
ENV["DATADEPS_ALWAY_ACCEPT"]=true

RegisterDataDep(
                "test",
                "These are test data including an `nd` file and multiple dark and light timelapse 16 bit TIF images (1.6 GB total).",
"https://s3.eu-central-1.amazonaws.com/yakirgagnon/roots/test.zip",
"b98f13389b6ed91ae0c546ccf2d6026b371cb0bf94e750124c62bbf6f680a3a2",
post_fetch_method=unpack
)

@testset "basic" begin

    files = readdir(datadep"test")
    i = findfirst(x -> last(splitext(x)) == ".nd", files)
    @test_nowarn md = TrackRoots.nd2metadata(joinpath(datadep"test", files[i]))
    @test md.n == 2

end




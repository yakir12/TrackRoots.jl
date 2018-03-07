ENV["PLOTS_TEST"] = "true"
ENV["GKSwstype"] = "100"
using TrackRoots
using Base.Test

using DataDeps
ENV["DATADEPS_ALWAY_ACCEPT"]=true
RegisterDataDep("test",
                "These are some folders with their `nd` files and multiple dark and light timelapse 16 bit TIF images (2.9 GB total).",
                "https://s3.eu-central-1.amazonaws.com/yakirgagnon/roots/test.zip",
                "84453b6d4e84ad1244210d6bffcfd5916c15097f790925888148db90c3d148a7",
                post_fetch_method=unpack)

import TrackRoots:Point
@testset "utils" begin

    a = TrackRoots.disk(1)
    @test all(CartesianIndex(i) ∈ a for i in [(-1,0), (0,-1), (0,0), (0,1), (1,0)])

end

startpoints = [[Point[[774.3011654713115, 911.7642161885246]]], [Point[[534.2970350922132, 378.69399574154716]], Point[[726.5627041175717, 437.72684385873276]]], [Point[[470.9424388447746, 523.4365954789959]], Point[[372.28236264088116, 549.768298539959]], Point[[438.7849781474129, 278.5611512231045]]], [Point[[544.1841620773565, 523.4520763960041]], Point[[538.4051933913935, 509.97839191531347]], Point[[622.5830918609118, 246.14959616739242]], Point[[610.663294057377, 398.3634653560451]]], [Point[[761.334080430328, 413.93003970286884]], Point[[811.9541095671107, 510.3906089907787]]], [Point[[527.7699234759222, 344.6583472079918]], Point[[773.229998479124, 565.6303750635162]], Point[[551.95458984375, 567.2299244364754]]], [Point[[922.8385229892418, 487.0387503201844]], Point[], Point[[839.9598168545082, 676.9329673830143]], Point[[401.7507044057377, 434.2714283427254]]], [Point[], Point[], Point[[701.4121974257172, 603.8230660860656]], Point[[655.2376889088115, 595.7405865778688]]]]
endpoints = [[Point[[904.9364522125379, 919.0443242002601]]], [Point[[759.7339585464049, 349.67100009834166]], Point[[1000.7755448226577, 469.9146794776227]]], [Point[[514.1614073576073, 536.7196266118772]], Point[[407.55891865815, 546.7966992882476]], Point[[474.35621036315683, 278.8619310200936]]], [Point[[621.3929471402455, 525.7630664775759]], Point[[630.1256138547242, 533.5702963300903]], Point[[688.7103937141497, 250.73057010728078]], Point[[731.2364672532566, 380.72190178371096]]], [Point[[1017.0597835688507, 208.98726714885305]], Point[[1017.5227104153928, 315.23929042231043]]], [Point[[730.2535639964862, 327.895086031576]], Point[[1016.0545626838322, 551.2542723648528]], Point[[945.5572309663199, 590.5367953365943]]], [Point[[1018.1700183076565, 471.4396372953533]], Point[], Point[[1017.8463747258998, 644.4757666777125]], Point[[572.0582086956706, 423.6265374344757]]], [Point[], Point[], Point[[920.6710051005372, 506.12034261277336]], Point[[774.1214888186025, 421.7462369106153]]]]

@testset "all" begin
    for dataset in [1,5,6,7]
        files = readdir(joinpath(datadep"test", string(dataset)))
        i = findfirst(x -> last(splitext(x)) == ".nd", files)
        ndfile = joinpath(datadep"test", string(dataset), files[i])
        stages = TrackRoots.nd2stages(ndfile)
        calibstages = TrackRoots.stages2calib(stages)
        tracks = TrackRoots.trackroot.(calibstages, startpoints[dataset])
        endpoint = map(tracks) do t
            map(t) do r
                r.coordinates[end]
            end
        end
        @test endpoints[dataset] == endpoint
    end
end

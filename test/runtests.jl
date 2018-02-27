using Plots
using Base.Test

@testset "main" begin
    anim = Animation()
    for i in 1:3
        plot(rand(10))
        Plots.frame(anim)
    end
    name = tempname()*".gif"
    gif(anim, name, fps = 30)
    @test isfile(name)
end

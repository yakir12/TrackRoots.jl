using Base.Test, Plots
anim = @animate for i=1:2
    plot(rand(2))
end
name = tempname()*".gif"
gif(anim, name)
@test isfile(name)

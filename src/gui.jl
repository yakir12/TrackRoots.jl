using Makie, GeometryTypes, Colors, Images
using TrackRoots
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
using DataDeps
RegisterDataDep("all",
                "These are all 8 folders with their `nd` files and multiple dark and light timelapse 16 bit TIF images (7.8 GB total).",
                "https://s3.eu-central-1.amazonaws.com/yakirgagnon/roots/eight_folders.zip",
                "c316452c19e3c639737821581d18e45654980e04e0244f3d43e30d47d3e81f11",
                post_fetch_method=unpack)
i = 8
files = readdir(joinpath(datadep"all", string(i)))
j = findfirst(x -> last(splitext(x)) == ".nd", files)
md = TrackRoots.nd2metadata(joinpath(datadep"all", string(i), files[j]))
img = load(md.stages[1].timelapse[1].dark.path)
img = imadjustintensity(img, quantile(vec(Float64.(img)), [.1, .995]))
scene = Scene(resolution=(sz, sz))
heatmap(img)
center!(scene, 0)
cam = scene[:screen].cameras[:orthographic_pixel]
Makie.add_mousebuttons(scene)
clicks = to_node(Point2f0[])
pos = lift_node(scene, :mousebuttons) do buttons
    if length(buttons) == 1 
        if first(buttons) == Mouse.left
            pos = to_world(Point2f0(to_value(scene, :mouseposition)), cam)
            # awkward! one push! for adding to clicks, another to update the node!
            push!(clicks, push!(to_value(clicks), pos))
        #=elseif first(buttons) == Mouse.right 
            pos = to_world(Point2f0(to_value(scene, :mouseposition)), cam)
            kill = map(enumerate(clicks.signal.value)) do ixy
                if norm(last(ixy) - pos) < 100
                    return first(ixy)
                end
            end
            !isempty(kill) && deleteat!(clicks.signal.value, kill)=#
        end
    end
    return 
end
scatter(clicks, markersize = 10)
wait(scene)
println(clicks.signal.value)

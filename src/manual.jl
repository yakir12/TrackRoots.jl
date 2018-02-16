################################################################################
# Fill this with the desire values:
nd_file = "/home/yakir/.julia/datadeps/all/2/204.nd"
stage_number = 1
root_tips = [
             (649, 993), 
             (618, 919),
             (673, 821)
            ]
################################################################################


using TrackRoots
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))
md = nd2metadata(nd_file)
roots = mytrack(md.stages[stage_number], CartesianIndex.(root_tips))


m = reshape(1:30, 5, 6)
# using ImageAxes
using Unitful
import Unitful:mm
img = AxisArray(m, 
                Axis{:y}(1mm:1mm:5mm),
                Axis{:x}(1mm:1mm:6mm))

img[atindex(-1mm..1mm, 4), atindex(-1mm..1mm, 2)]

using AxisArrays
B = AxisArray(randn(100,100,100), :x, :y, :z)
Itotal = sumz = 0.0
for iter in CartesianRange(indices(B))  # traverses in storage order for cache efficiency
    I = B[iter]  # intensity in a single voxel
    Itotal += I
    sumz += I * iter[axisdim(B, Axis{:z})]  # axisdim "looks up" the z dimension
end
meanz = sumz/Itotal


using Unitful
import Unitful:mm
B = AxisArray(randn(100,100,100), Axis{:x}(1:100), Axis{:y}(1:100), Axis{:z}(linspace(1mm,3mm,100)))

Itotal = sumz = 0.0
for iter in CartesianRange(indices(B))  # traverses in storage order for cache efficiency
    I = B[iter]  # intensity in a single voxel
    Itotal += I
    sumz += I * iter[axisdim(B, Axis{:z})]  # axisdim "looks up" the z dimension
end
meanz = sumz/Itotal

    axisvalues(axes(B, Axis{:z}))[1][45]

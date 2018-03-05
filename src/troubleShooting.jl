using Images, ImageView, GtkReactive
include(joinpath(Pkg.dir("TrackRoots"), "src", "utils.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "stages.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "calibrates.jl"))
include(joinpath(Pkg.dir("TrackRoots"), "src", "tracks.jl"))

ndfile = "/home/yakir/.julia/datadeps/all/5/cle44-luc-bfa3.nd"
stages = nd2stages(ndfile)

calibstages = stages2calib(stages)
startpointss = [[Point(761.592, 414.589)]]
st = calibstages[1]
startpoints = startpointss[1]

vrow = speed/st.speed
roots = [Root(p, vrow) for p in startpoints]
tracks = [Track(p, st, i) for (i, p) in enumerate(startpoints)]
for i in 2:20
    tl1, tl2 = (st.timelapse[i], st.timelapse[i+1])
    img = load(tl1.path)
    r, t = (roots[1], tracks[1])
    t1, t2 = (tl1.time, tl2.time)
    g = imshow(img)
    ImageView.annotate!(g, AnnotationPoint(r.x[2], r.x[1], shape='.', size=2, color=RGB(1,0,0)))
    x, Ppred, A = Kalman.predict!(t1, r.x, r.P, t2, r.model)
    ImageView.annotate!(g, AnnotationPoint(x[2], x[1], shape='.', size=2, color=RGB(0,1,0)))
    y = image_feedback(img, Point(x[1:2]...))
    ImageView.annotate!(g, AnnotationPoint(y[2], y[1], shape='.', size=2, color=RGB(0,0,1)))
    _, obs, C, R = Kalman.observe!(t1, x, r.P, t2, y, r.model)
    x, P, yres, S, K = Kalman.correct!(x, Ppred, obs, C, R, r.model)
    ImageView.annotate!(g, AnnotationPoint(x[2], x[1], shape='.', size=2, color=RGB(1,0,1)))
    r.x = x
    r.P = P
end

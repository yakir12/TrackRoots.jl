"""
Use Model `M` to track blurry light sources through
frames in imgs. `X0` are the locations and `P0` 
uncertainty of the locations. 
`params` are arguments to `track`, eg. window-size.

Returns matrix of the filtered states with a row per light sources
and a column per frame.
"""
function trackandfilter(M, imgs, X0, P0, params...)
    nframe = size(imgs, 3)
    pp = fill(zero(M.x0), nframe, length(X0))
    ll = zeros(length(X0))
    for k in 1:length(X0)
        x = X0[k]
        P = P0[k]
        l = 0.0
        for t in 1:nframe
            x, Ppred, A = Kalman.predict!(t, x, P, t + 1, M)
            y, err = track(view(imgs, :, :, t), x, params...)
            _, obs, C, R = Kalman.observe!(t, x, P, t + 1, y, M)
            x, P, yres, S, K = Kalman.correct!(x, Ppred, obs, C, R, M)
            l += Kalman.llikelihood(yres, S, M)
            pp[t, k] = x
        end
        ll[k] = l
    end
    pp, ll
end
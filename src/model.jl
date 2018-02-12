"""
`v` is the typical velocity vector and
`0 < ρ <= 1` is a parameter regulating how strongly
the system is attracted to attain velocity `v`.
"""
model(ρ, v) = let
    p0 = [NaN, NaN, 0.0, v]
    P0 = 10*eye(4)

    A = [1.0 0.0 1.0 0.0
        0.0 1.0 0.0 1.0
        0.0 0.0 ρ 0.0
        0.0 0.0 0.0 ρ
    ]

    b = [0.0, 0.0, (1-ρ)*v[1], (1-ρ)*v[2]]
    Q = 1*diagm([1.0, 1.0, 5.0, 5.0])

    y = [NaN, NaN]
    C = eye(2, 4)
    R = 2eye(2)

    LinearHomogSystem(p0, P0, A, b, Q, y, C, R)
end

Model1 = let
    p0 = [NaN, NaN, 0.0, 2.0]
    P0 = 10*eye(4)

    A = [1.0 0.0 1.0 0.0
        0.0 1.0 0.0 1.0
        0.0 0.0 1.0 0.0
        0.0 0.0 0.0 1.0
    ]

    b = [0.0, 0.0, 0.0, 0.0]
    Q = 1*diagm([1.0, 1.0, 5.0, 5.0])

    y = [NaN, NaN]
    C = eye(2, 4)
    R = 2eye(2)

    LinearHomogSystem(p0, P0, A, b, Q, y, C, R)
end


function tostatic(M::LinearHomogSystem) 
    d2, d = Kalman.dims(M)
    LinearHomogSystem(SVector{d}(M.x0), 
    SMatrix{d,d}(M.P0),
    SMatrix{d,d}(M.Phi),
    SVector{d}(M.b),
    SMatrix{d,d}(M.Q),
    SVector{d2}(M.y),
    SMatrix{d2,d}(M.H),
    SMatrix{d2,d2}(M.R))
end
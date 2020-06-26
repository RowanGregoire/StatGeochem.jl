## --- Math.jl

    @test normpdf.(0,1,-1:1) ≈ [0.24197072451914337, 0.3989422804014327, 0.24197072451914337]
    @test norm_width.(0:0.25:1) ≈ [-Inf, -1.6832424671458286, -0.8614545985909146, -0.3600247395854099, 0.0]

    @test inpolygon([-1,0,1,0],[0,1,0,-1],[0,0])
    @test all( arcdistance(0,100,[30,0,0],[100,100,95]) .≈ [30,0,5] )

## --

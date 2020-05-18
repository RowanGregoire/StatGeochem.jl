## --- ArrayStats.jl

    # Simple functions
    A = [1:10.0..., NaN]
    @test nansum(A) == 55.0
    @test nanmean(A) == 5.5
    @test nanrange(A) == 9.0
    @test nanminimum(A) == 1.0
    @test nanmaximum(A) == 10.0
    @test nanextrema(A) == (1.0, 10.0)
    @test nanstd([1,2,3,NaN]) == 1.0
    @test nanmad([1,2,3,NaN]) == 1.0
    @test nanaad([1,2,3,NaN]) ≈ 2/3
    @test nanmedian([1,2,3,NaN]) == 2.0
    @test pctile([0:100...,NaN],99) == 99.0

    # Dimensional tests
    @test nanminimum(reshape(1:300,100,3), dims=1) == minimum(reshape(1:300,100,3), dims=1)
    @test nanminimum(reshape(1:300,100,3), dims=2) == minimum(reshape(1:300,100,3), dims=2)
    @test nanmaximum(reshape(1:300,100,3), dims=1) == maximum(reshape(1:300,100,3), dims=1)
    @test nanmaximum(reshape(1:300,100,3), dims=2) == maximum(reshape(1:300,100,3), dims=2)
    @test nanmean(reshape(1:300,100,3), dims=1) == mean(reshape(1:300,100,3), dims=1)
    @test nanmean(reshape(1:300,100,3), dims=2) == mean(reshape(1:300,100,3), dims=2)
    @test nanstd(reshape(1:300,100,3), dims=1) == std(reshape(1:300,100,3), dims=1)
    @test nanstd(reshape(1:300,100,3), dims=2) == std(reshape(1:300,100,3), dims=2)
    @test nanmad(reshape(1:300,100,3), dims=1) == [25.0 25.0 25.0]
    @test nanmad(reshape(1:300,100,3), dims=2) == fill(100.0,100,1)
    @test nanaad(reshape(1:300,100,3), dims=1) == [25.0 25.0 25.0]
    @test nanaad(reshape(1:300,100,3), dims=2) ≈ fill(200/3,100,1)
    @test nanmedian(reshape(1:300,100,3), dims=1) == median(reshape(1:300,100,3), dims=1)
    @test nanmedian(reshape(1:300,100,3), dims=2) == median(reshape(1:300,100,3), dims=2)

    # Binning
    @test nanmean([1:100..., 1],[1:100..., NaN],0,100,3) == [17, 50, 83]
    @test nanmean(1:100, reshape(1:300,100,3), 0, 100, 3) ==
                [17.0 117.0 217.0; 50.0 150.0 250.0; 83.0 183.0 283.0]
    @test nanmedian([1:100..., 1],[1:100..., NaN],0,100,3) == [17, 50, 83.5]
    @test nanmedian(1:100, reshape(1:300,100,3), 0, 100, 3) ==
                [17.0 117.0 217.0; 50.0 150.0 250.0; 83.5 183.5 283.5]

    # Moving averages
    @test movmean(collect(1:10.),5) == movmean(1:10,5)
    @test movmean(1:10,4) == [2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 8.5, 9.0]

    # Weighted Means
    @test MSWD([0,1,2],[1,1,1]) == 1.0
    @test awmean([0,1,2,3],[1,1,1,1]) == (1.5, 0.5, 5/3)
    @test gwmean([0,1,2,3],[1,1,1,1]) == (1.5, 0.6454972243679028, 5/3)


## --- Math.jl

    @test inpolygon([-1,0,1,0],[0,1,0,-1],[0,0])
    @test all( arcdistance(0,100,[30,0,0],[100,100,95]) .≈ [30,0,5] )

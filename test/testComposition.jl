# Test creating and normalizing Composition objects

x = NCKFMASHTOtrace((1.0:length(fieldnames(NCKFMASHTOtrace)))...,)
@test x isa NCKFMASHTOtrace{Float64}
@test x === NCKFMASHTOtrace{Float64}(1:40)
@test ntuple(x) === ntuple(Float64, 40)
xn = normalize(x) 
@test sum(e->xn[e], majorelements(xn)) ≈ 99.86110228500358 
xn = normalize(dehydrate(x)) 
@test sum(e->xn[e], majorelements(xn)) ≈ 99.83028850953377
xn = normalize(x, anhydrous=true) 
@test sum(e->xn[e], propertynames(xn)[1:9]) ≈ 99.83028850953377
@test propertynames(xn)[1:10] == majorelements(xn) == majorelements(NCKFMASHTOtrace)
@test propertynames(xn)[11:40] == traceelements(xn) == traceelements(NCKFMASHTOtrace)
@test xn isa NCKFMASHTOtrace{Float64}
@test 0.5*xn + 0.5*xn == xn
@test !isnan(xn)
@test isnan(xn * NaN)

x = NCKFMASHTOlogtrace(x)
@test x isa NCKFMASHTOlogtrace{Float64}
@test x === NCKFMASHTOlogtrace{Float64}([1:10; log.(11:40)])
@test ntuple(x) === ((1:10.)..., log.(11:40)...,)
xn = normalize(x) 
@test xn isa NCKFMASHTOlogtrace{Float64}
@test sum(e->xn[e], majorelements(xn)) ≈ 99.86110228500358 
xn = normalize(dehydrate(x)) 
@test sum(e->xn[e], majorelements(xn)) ≈ 99.83028850953377
xn = normalize(x, anhydrous=true) 
@test sum(e->xn[e], propertynames(xn)[1:9]) ≈ 99.83028850953377
@test propertynames(xn)[1:10] == majorelements(xn) == majorelements(NCKFMASHTOlogtrace)
@test propertynames(xn)[11:40] == traceelements(xn) == traceelements(NCKFMASHTOlogtrace)
@test xn isa NCKFMASHTOlogtrace{Float64}
@test 0.5*xn + 0.5*xn == xn
@test !isnan(xn)
@test isnan(xn * NaN)

x = NCKFMASHTOCrtrace((1.0:length(fieldnames(NCKFMASHTOCrtrace)))...,)
@test x isa NCKFMASHTOCrtrace{Float64}
@test x === NCKFMASHTOCrtrace{Float64}(1:40)
@test ntuple(x) === ntuple(Float64, 40)
xn = normalize(x) 
@test sum(e->xn[e], majorelements(xn)) ≈ 99.8858879401411
xn = normalize(dehydrate(x)) 
@test sum(e->xn[e], majorelements(xn)) ≈ 99.86309677278784
xn = normalize(x, anhydrous=true) 
@test sum(e->xn[e], propertynames(xn)[1:10]) ≈ 99.86309677278784
@test propertynames(xn)[1:11] == majorelements(xn) == majorelements(NCKFMASHTOCrtrace)
@test propertynames(xn)[12:40] == traceelements(xn) == traceelements(NCKFMASHTOCrtrace)
@test xn isa NCKFMASHTOCrtrace{Float64}
@test 0.5*xn + 0.5*xn == xn
@test !isnan(xn)
@test isnan(xn * NaN)

x = NCKFMASHTOCrlogtrace(x)
@test x isa NCKFMASHTOCrlogtrace{Float64}
@test x === NCKFMASHTOCrlogtrace{Float64}([1:11; log.(12:40)])
@test ntuple(x) === ((1:11.)..., log.(12:40)...,)
xn = normalize(x) 
@test sum(e->xn[e], majorelements(xn)) ≈ 99.8858879401411
xn = normalize(dehydrate(x)) 
@test sum(e->xn[e], majorelements(xn)) ≈ 99.86309677278784
xn = normalize(x, anhydrous=true) 
@test sum(e->xn[e], propertynames(xn)[1:10]) ≈ 99.86309677278784
@test propertynames(xn)[1:11] == majorelements(xn) == majorelements(NCKFMASHTOCrlogtrace)
@test propertynames(xn)[12:40] == traceelements(xn) == traceelements(NCKFMASHTOCrlogtrace)
@test xn isa NCKFMASHTOCrlogtrace{Float64}
@test 0.5*xn + 0.5*xn == xn
@test !isnan(xn)
@test isnan(xn * NaN)

# Composition distributions
μ = rand(40)
Σ = [Float64(i==j) for i in 1:40, j in 1:40]
d = CompositionNormal(NCKFMASHTOCrtrace{Float64}, μ, Σ)
@test d isa CompositionNormal{Float64, NCKFMASHTOCrtrace{Float64}}
@test d isa StatGeochem.CompositionDistribution{NCKFMASHTOCrtrace{Float64}}
@test rand(d) isa NCKFMASHTOCrtrace{Float64}
@test rand(d,10) isa Vector{NCKFMASHTOCrtrace{Float64}}

# Composition arrays
ca = CompositionArray{NCKFMASHTOCrtrace{Float64}}(undef, 99)
@test ca isa CompositionArray{NCKFMASHTOCrtrace{Float64}}
@test ca[1] isa NCKFMASHTOCrtrace{Float64}
@test ca[1:10] isa CompositionArray{NCKFMASHTOCrtrace{Float64}}
@test view(ca, 1:10) isa CompositionArray{NCKFMASHTOCrtrace{Float64}}
@test copy(ca[1:10]) isa CompositionArray{NCKFMASHTOCrtrace{Float64}}
@test length(ca) === 99
@test eachindex(ca) === Base.OneTo(99)
@test ca.SiO2 isa Vector{Float64}
@test length(ca.SiO2) === 99
@test eachindex(ca.SiO2) === Base.OneTo(99)
@test ca.SiO2 === ca[:SiO2]
@test ca.La isa Vector{Float64}
@test length(ca.La) === 99
@test eachindex(ca.La) === Base.OneTo(99)
@test ca.La === ca[:La]

# Randomize and normalize composition arrays
StatGeochem.rand!(ca)
@test nanmean(ca.SiO2) ≈ 10 atol = 2
@test sum(e->ca[1][e], majorelements(ca)) ≈ 99.99 atol=0.02
renormalize!(ca; anhydrous=true)
@test sum(e->ca[1][e], filter(x->!(x===:H2O), majorelements(ca)))  ≈ 99.99 atol=0.02

cam = partiallymix!(copy(ca), 1)
@test cam[50] ≈ 0.5*ca[1] + 0.5*ca[99]
@test isnormalized(cam[50], anhydrous=true)
@test !isnormalized(cam[50], anhydrous=false)
cam = partiallymix!(copy(ca), 0.5)
@test cam[50] ≈ 0.5ca[50] + 0.5(0.5*ca[1] + 0.5*ca[99])
@test isnormalized(cam[50], anhydrous=true)

ca = CompositionArray{NCKFMASHTOlogtrace{Float64}}(undef, 99)
StatGeochem.rand!(ca)
@test nanmean(ca.SiO2) ≈ 10 atol = 2
@test sum(e->ca[1][e], majorelements(ca)) ≈ 99.99 atol=0.02
renormalize!(ca; anhydrous=true)
@test sum(e->ca[1][e], filter(x->!(x===:H2O), majorelements(ca)))  ≈ 99.99 atol=0.02

cam = partiallymix!(copy(ca), 1)
@test cam[50] ≈ 0.5*ca[1] + 0.5*ca[99]
@test isnormalized(cam[50], anhydrous=true)
@test !isnormalized(cam[50], anhydrous=false)
cam = partiallymix!(copy(ca), 0.5)
@test cam[50] ≈ 0.5ca[50] + 0.5(0.5*ca[1] + 0.5*ca[99])
@test isnormalized(cam[50], anhydrous=true)
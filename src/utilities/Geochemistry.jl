## --- Calculate Eu*

    """
    ```julia
    eustar(Nd::Number, Sm::Number, Gd::Number, Tb::Number)
    ```
    Calculate expected europium concentration, Eu*, based on abundance of
    adjacent rare earths.

    Full four-element log-linear interpolation, using ionic radii
    """
    function eustar(Nd::Number, Sm::Number, Gd::Number, Tb::Number)
        # Ionic radii, in pm [Tb, Gd, Sm, Nd]
        r = [106.3, 107.8, 109.8, 112.3] # or x = [1, 2, 4, 6]

        # Normalize to chondrite
        y = log.([Tb/0.0374, Gd/0.2055, Sm/0.1530, Nd/0.4670])
        notnan = .!isnan.(y)

        # Make sure we're interpolating and not extrapolating
        if any(view(notnan, 1:2)) && any(view(notnan, 3:4))
            # Fit a straight line through the chondrite-normalized values
            x = r[notnan]
            (a,b) = hcat(fill!(similar(x), 1), x) \ y[notnan]
            # De-dormalize output for Eu, interpolating at r = 108.7 pm or x = 3
            eu_interp = 0.0580*exp(a + b*108.7)
        else
            eu_interp = NaN
        end
        return eu_interp
    end

    """
    ```julia
    eustar(Sm::Number, Gd::Number)
    ```
    Calculate expected europium concentration, Eu*, based on abundance of
    adjacent rare earths.

    Simple geometric mean interpolation from Sm and Gd alone
    """
    function eustar(Sm::Number, Gd::Number)
        # Geometric mean in regular space is equal to the arithmetic mean in log space. Fancy that!
        return 0.0580*sqrt(Sm/0.1530 * Gd/0.2055)
    end

    export eustar

## --- CIPW norm

    """
    ```julia
    cipw_norm(SiO2, TiO2, Al2O3, Fe2O3, FeO, MnO, MgO, CaO, Na2O, K2O, P2O5)
    ```
    Returns
    ```
    quartz, orthoclase, plagioclase, corundum, nepheline, diopside, orthopyroxene, olivine, magnetite, ilmenite, apatite
    ```
    """
    function cipw_norm(SiO2, TiO2, Al2O3, Fe2O3, FeO, MnO, MgO, CaO, Na2O, K2O, P2O5)
        SiO2  /= 60.0843
        TiO2  /= 79.8988
        Al2O3 /= 101.9613
        Fe2O3 /= 159.6922
        FeO  /= 71.8464
        MnO  /= 70.9374
        MgO  /= 40.3044
        CaO  /= 56.0794
        Na2O /= 61.9789
        K2O  /= 94.1960
        P2O5 /= 141.9445

        FeO = nanadd(FeO, MnO)
        CaO -= 3.333333333333333 * P2O5
        apatite = 0.6666666666666666 * P2O5
        # P2O5 = 0
        FeO -= TiO2
        ilmenite = TiO2
        FeO -= Fe2O3
        magnetite = Fe2O3
        # Fe2O3 = 0
        Al2O3 -= K2O
        orthoclase = K2O
        # K2O = 0
        Al2O3 -= Na2O
        albite = Na2O
        if CaO > Al2O3
            CaO -= Al2O3
            anorthite = Al2O3
            Al2O3 = 0
        else
            Al2O3 -= CaO
            anorthite = CaO
            CaO = 0
        end
        if Al2O3 > 0
            corundum = Al2O3
            Al2O3 = 0
        else
            corundum = 0
        end
        Mg′ = MgO / (MgO + FeO)
        FMO = FeO + MgO
        FMO_weight = (Mg′*40.3044)+((1-Mg′)*71.8464)
        if CaO > 0
            FMO -= CaO
            diopside = CaO
        else
            diopside = 0
        end
        orthopyroxene = FMO
        pSi1 = 6orthoclase + 6albite + 2anorthite + 2diopside + orthopyroxene
        if pSi1 < SiO2
            quartz = SiO2 - pSi1
            nepheline = 0
            olivine = 0
        else
            quartz = 0
            pSi2 = 6orthoclase + 6albite + 2anorthite + 2diopside
            pSi3 = SiO2 - pSi2
            if FMO > 2pSi3
                orthopyroxene = 0
                olivine = FMO
                FMO = 0
                pSi4 = 6orthoclase + 2anorthite + 2diopside + 0.5olivine
                pSi5 = SiO2 - pSi4
                Albite = (pSi5-(2*Na2O))/4
                nepheline = Na2O-Albite
            else
                nepheline = 0
                orthopyroxene = 2pSi3 - FMO
                olivine = FMO - pSi3
            end
        end
        orthoclase *= 2
        nepheline *= 2
        albite *= 2
        An′ = anorthite/(anorthite+albite)
        plag_weight = (An′*278.2093)+((1-An′)*262.2230)
        plagioclase = albite+anorthite

        quartz *= 60.0843
        orthoclase *= 278.3315
        plagioclase *= plag_weight
        corundum *= 101.9613
        nepheline *= 142.0544
        diopside *= (172.248 + FMO_weight)
        orthopyroxene *= (60.0843 + FMO_weight)
        olivine *= (60.0843 + 2FMO_weight)
        magnetite *= 231.5386
        ilmenite *= 151.7452
        apatite *= 504.3152

        return (quartz=quartz, orthoclase=orthoclase, plagioclase=plagioclase,
            corundum=corundum, nepheline=nepheline, diopside=diopside,
            orthopyroxene=orthopyroxene, olivine=olivine, magnetite=magnetite,
            ilmenite=ilmenite, apatite=apatite)
    end
    # export cipw_norm

## --- Fe oxide conversions

    """
    ```julia
    feoconversion(FeO::Number=NaN, Fe2O3::Number=NaN, FeOT::Number=NaN, Fe2O3T::Number=NaN)
    ```
    Compiles data from FeO, Fe2O3, FeOT, and Fe2O3T into  a single FeOT value.
    """
    function feoconversion(FeO::Number=NaN, Fe2O3::Number=NaN, FeOT::Number=NaN, Fe2O3T::Number=NaN)

        # To convert from Fe2O3 wt % to FeO wt %, multiply by
        conversionfactor = (55.845+15.999) / (55.845+1.5*15.999)

        # If FeOT or Fe2O3T already exists, use that
        if isnan(FeOT)
            if isnan(Fe2O3T)
                FeOT=nanadd(Fe2O3*conversionfactor, FeO)
            else
                FeOT=Fe2O3T*conversionfactor
            end
         end

        return FeOT
    end
    export feoconversion

## --- Oxide conversions

    """
    ```julia
    dataset = oxideconversion(dataset::Dict; unitratio::Number=10000)
    ```
    Convert major elements (Ti, Al, etc.) into corresponding oxides (TiO2, Al2O3, ...).

    If metals are as PPM, set unitratio=10000 (default); if metals are as wt%,
    set unitratio = 1
    """
    function oxideconversion(dataset::Dict; unitratio::Number=10000)
        result = copy(dataset)
        return oxideconversion!(result)
    end
    export oxideconversion
    """
    ```julia
    dataset = oxideconversion!(dataset::Dict; unitratio::Number=10000)
    ```
    Convert major elements (Ti, Al, etc.) into corresponding oxides (TiO2, Al2O3, ...) in place.

    If metals are as PPM, set unitratio=10000 (default); if metals are as wt%,
    set unitratio = 1
    """
    function oxideconversion!(dataset::Dict; unitratio::Number=10000)
        # Convert major elements (Ti, Al, etc.) into corresponding oxides (TiO2, Al2O3)...
        # for i ∈ eachindex(source)
        #     conversionfactor(i)=mass.percation.(dest[i])./mass.(source[i]);
        # end

        # Array of elements to convert
        source = ["Si","Ti","Al","Fe","Fe","Mg","Ca","Mn","Li","Na","K","P","Cr","Ni","Co","C","S","H"]
        dest = ["SiO2","TiO2","Al2O3","FeOT","Fe2O3T","MgO","CaO","MnO","Li2O","Na2O","K2O","P2O5","Cr2O3","NiO","CoO","CO2","SO2","H2O"]
        conversionfactor = [2.13932704290547,1.66847584248889,1.88944149488507,1.28648836426407,1.42973254639611,1.65825961736268,1.39919258253823,1.29121895771597,2.1526657060518732,1.34795912485574,1.20459963614796,2.29133490474735,1.46154369861159,1.27258582901258,1.27147688434143,3.66405794688203,1.99806612601372,8.93601190476191]

        # If source field exists, fill in destination from source
        for i ∈ eachindex(source)
            if haskey(dataset, source[i])
                if ~haskey(dataset, dest[i]) # If destination field doesn't exist, make it.
                    dataset[dest[i]] = fill(NaN, size(dataset[source[i]]))
                end
                t = isnan.(dataset[dest[i]]) .& (.~ isnan.(dataset[source[i]]))
                dataset[dest[i]][t] = dataset[source[i]][t] .* (conversionfactor[i] / unitratio)
            end
        end

        return dataset
    end
    export oxideconversion!


## --- Chemical Index of Alteration

    # Chemical Index of Alteration as defined by Nesbitt and Young, 1982
    # Note that CaO should be only igneous CaO excluding any Ca from calcite or apatite
    function CIA(Al2O3::Number, CaO::Number, Na2O::Number, K2O::Number)
        A = Al2O3 / 101.96007714
        C = CaO / 56.0774
        N = Na2O / 61.978538564
        K = K2O / 94.19562
        return A / (A + C + N + K) * 100
    end
    export CIA

    # "Weathering Index of Parker" as defined by Parker, 1970
    function WIP(Na2O::Number, MgO::Number, K2O::Number, CaO::Number)
        Na = Na2O / 30.9895
        Mg = MgO / 40.3044
        K = K2O / 47.0980
        Ca = CaO / 56.0774
        # Denominator for each element is a measure of Nicholls' bond strengths
        return (Na/0.35 + Mg/0.9 + K/0.25 + Ca/0.7) * 100
    end
    export WIP

## --- MELTS interface

    """
    ```julia
    melts_configure(meltspath::String, scratchdir::String, composition::AbstractArray{<:Number},
        \telements::AbstractArray{String},
        \tT_range=(1400, 600),
        \tP_range=(10000,10000);)
    ```
    Configure and run a MELTS simulation using alphaMELTS.
    Optional keyword arguments and defaults include:

        batchstring::String = "1\nsc.melts\n10\n1\n3\n1\nliquid\n1\n1.0\n0\n10\n0\n4\n0\n"

    A string defining the sequence of options that would be entered to produce
    the desired calculation if running alphaMELTS at the command line. The
    default string specifies a batch calculation starting at the liquidus.

        dT = -10

    The temperature step, in degrees, between each step of the MELTS calculation

        dP = 0

    The pressure step, in bar, between each step of the MELTS calculation

        index = 1

    An optional variable used to specify a unique suffix for the run directory name

        version::String = "pMELTS"

    A string specifying the desired version of MELTS. Options include `MELTS` and `pMELTS`.

        mode::String = "isobaric"

    A string specifying the desired calculation mode for MELTS. Options include
    `isothermal`, `isobaric`, `isentropic`, `isenthalpic`, `isochoric`,
    `geothermal` and `PTPath`.

        fo2path::String = "FMQ"

    A string specifying the oxygen fugacity buffer to follow, e.g., `FMQ` or `NNO+1`.
    Available buffers include `IW`,`COH`,`FMQ`,`NNO`,`HM`, and `None`

        fractionatesolids::Bool = false

    Fractionate all solids? default is `false`

        suppress::AbstractArray{String} = String[]

    Supress individual phases (specify as strings in array, i.e. `["leucite"]`)

        verbose::Bool = true

    Print verbose MELTS output to terminal (else, write it to `melts.log`)
    """
    function melts_configure(meltspath::String, scratchdir::String, composition::Collection{Number},
        elements::AbstractArray{String}, T_range::Collection{Number}=(1400, 600), P_range::Collection{Number}=(10000,10000);
        batchstring::String="1\nsc.melts\n10\n1\n3\n1\nliquid\n1\n1.0\n0\n10\n0\n4\n0\n",
        dT=-10, dP=0, index=1, version="pMELTS",mode="isobaric",fo2path="FMQ",
        fractionatesolids::Bool=false, suppress::AbstractArray{String}=String[], verbose::Bool=true)

        ############################ Default Settings ###############################
        ##MELTS or pMELTS
        #version = "pMELTS"
        ##Mode (isothermal, isobaric, isentropic, isenthalpic, isochoric, geothermal or PTPath)
        #mode = "isobaric"
        ## Set fO2 constraint, i.e. "IW","COH","FMQ","NNO","HM","None" as a string
        #fo2path = "FMQ"
        ## Fractionate all solids? ("!" for no, "" for yes)
        #fractionatesolids = "!"
        # Mass retained during fractionation
        massin = 0.001
        # Ouptut temperatures in celcius? ("!" for no, "" for yes)
        celciusoutput = ""
        # Save all output? ("!" for no, "" for yes)
        saveall = "!"
        # Fractionate all water? ("!" for no, "" for yes)
        fractionatewater = "!"
        # Fractionate individual phases (specify as strings in cell array, i.e. {"olivine","spinel"})
        fractionate = String[]
        # Coninuous (fractional) melting? ("!" for no, "" for yes)
        continuous = "!"
        # Threshold above which melt is extracted (if fractionation is turned on)
        minf = 0.005
        # Do trace element calculations
        dotrace = "!"
        # Treat water as a trace element
        dotraceh2o = "!"
        # Initial trace compositionT
        tsc = Float64[]
        # Initial trace elements
        telements = String[]
        # Default global constraints
        Pmax = 90000
        Pmin = 2
        Tmax = 3000
        Tmin = 450
        # Simulation number (for folder, etc)

        ########################## end Default Settings ############################

        # Guess if intention is for calculation to end at Tf or Pf as a min or max
        if last(T_range)<first(T_range)
            Tmin=last(T_range)
        end
        if last(T_range)>first(T_range)
            Tmax=last(T_range)
        end
        if last(P_range)<first(P_range)
            Pmin=last(P_range)
        end
        if last(P_range)>first(P_range)
            Pmax=last(P_range)
        end

        if fractionatesolids
            fractionatesolids = ""
        else
            fractionatesolids = "!"
        end

        # Normalize starting composition
        composition = composition./sum(composition)*100

        # output prefixectory name
        prefix = joinpath(scratchdir, "out$(index)/")
        # Ensure directory exists and is empty
        system("rm -rf $prefix; mkdir -p $prefix")

        # Make .melts file containing the starting composition you want to run simulations on
        fp = open(prefix*"sc.melts", "w")
        for i ∈ eachindex(elements)
            write(fp,"Initial Composition: $(elements[i]) $(trunc(composition[i],digits=4))\n")
        end
        for i ∈ eachindex(telements)
            write(fp, "Initial Trace: $(telements[i]) $(trunc(tsc[i],digits=4))\n")
        end

        write(fp, "Initial Temperature: $(trunc(first(T_range),digits=2))\nInitial Pressure: $(trunc(first(P_range),digits=2))\nlog fo2 Path: $fo2path\n")

        for i ∈ eachindex(fractionate)
            write(fp,"Fractionate: $(fractionate[i])\n")
        end
        for i ∈ eachindex(suppress)
            write(fp,"Suppress: $(suppress[i])\n")
        end

        close(fp)


        # Make melts_env file to specify type of MELTS calculation
        fp = open(prefix*"/melts_env.txt", "w")
        write(fp, "! *************************************\n!  Julia-generated environment file\n! *************************************\n\n"  *
            "! this variable chooses MELTS or pMELTS; for low-pressure use MELTS\n" *
            "ALPHAMELTS_VERSION		$version\n\n" *
            "! do not use this unless fO2 anomalies at the solidus are a problem\n"  *
            "!ALPHAMELTS_ALTERNATIVE_FO2	true\n\n"  *
            "! use this if you want to buffer fO2 for isentropic, isenthalpic or isochoric mode\n! e.g. if you are doing isenthalpic AFC\n"  *
            "!ALPHAMELTS_IMPOSE_FO2		true\n\n"  *
            "! use if you want assimilation and fractional crystallization (AFC)\n"  *
            "!ALPHAMELTS_ASSIMILATE		true\n\n"  *
            "! isothermal, isobaric, isentropic, isenthalpic, isochoric, geothermal or PTPath\n"  *
            "ALPHAMELTS_MODE			$mode\n"  *
            "!ALPHAMELTS_PTPATH_FILE		ptpath.txt\n\n"  *
            "! need to set DELTAP for polybaric paths; DELTAT for isobaric paths\nALPHAMELTS_DELTAP	$(trunc(dP,digits=1))\n"  *
            "ALPHAMELTS_DELTAT	$(trunc(dT,digits=1))\n"  *
            "ALPHAMELTS_MAXP		$(trunc(Pmax,digits=1))\n"  *
            "ALPHAMELTS_MINP		$(trunc(Pmin,digits=1))\n"  *
            "ALPHAMELTS_MAXT		$(trunc(Tmax,digits=1))\n"  *
            "ALPHAMELTS_MINT		$(trunc(Tmin,digits=1))\n\n"  *
            "! this one turns on fractional crystallization for all solids\n! use Fractionate: in the melts file instead for selective fractionation\n"  *
            "$(fractionatesolids)ALPHAMELTS_FRACTIONATE_SOLIDS	true\n"  *
            "$(fractionatesolids)ALPHAMELTS_MASSIN		$massin\n\n"  *
            "! free water is unlikely but can be extracted\n"  *
            "$(fractionatewater)ALPHAMELTS_FRACTIONATE_WATER	true\n"  *
            "$(fractionatewater)ALPHAMELTS_MINW			0.005\n\n"  *
            "! the next one gives an output file that is always updated, even for single calculations\n"  *
            "$(saveall)ALPHAMELTS_SAVE_ALL		true\n"  *
            "!ALPHAMELTS_SKIP_FAILURE		true\n\n"  *
            "! this option converts the output temperature to celcius, like the input\n"  *
            "$(celciusoutput)ALPHAMELTS_CELSIUS_OUTPUT	true\n\n"  *
            "! the next two turn on and off fractional melting\n"  *
            "$(continuous)ALPHAMELTS_CONTINUOUS_MELTING	true\n"  *
            "$(continuous)ALPHAMELTS_MINF			$minf\n"  *
            "$(continuous)ALPHAMELTS_INTEGRATE_FILE	integrate.txt\n\n"  *
            "! the next two options refer to the trace element engine\n"  *
            "$(dotrace)ALPHAMELTS_DO_TRACE		true\n"  *
            "$(dotraceh2o)ALPHAMELTS_DO_TRACE_H2O		true\n")
        close(fp)

        # Make a batch file to run the above .melts file starting from the liquidus
        fp = open(prefix*"/batch.txt", "w")
        write(fp,batchstring)
        close(fp)

        # Run the command
        # Edit the following line(s to make sure you have a correct path to the "run_alphamelts.command" perl script
        if verbose
            system("cd " * prefix  * "; " * meltspath * " -f melts_env.txt -b batch.txt")
        else
            system("cd " * prefix  * "; " * meltspath * " -f melts_env.txt -b batch.txt &>./melts.log")
        end
        return 0
    end
    export melts_configure

    """
    ```julia
    melts_query(scratchdir::String; index=1)
    ```
    Read all phase proportions from `Phase_main_tbl.txt` in specified MELTS run directory
    Returns an elementified dictionary
    """
    function melts_query(scratchdir::String; index=1, importas=:Dict)
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        if importas==:Dict
            melts = Dict{String, Union{Vector{String}, Dict}}()
        else
            melts = Dict{String, Union{Vector{String}, NamedTuple}}()
        end
        if isfile(prefix*"/Phase_main_tbl.txt")
            data = readdlm(prefix*"/Phase_main_tbl.txt", ' ', skipblanks=false)
            pos = findall(all(isempty.(data), dims=2) |> vec)
            melts["minerals"] = Array{String}(undef, length(pos)-1)
            for i=1:(length(pos)-1)
                name = data[pos[i]+1,1]
                melts[name] = elementify(data[pos[i]+2:pos[i+1]-1,:], skipnameless=true, importas=importas)
                melts["minerals"][i] = name
            end
        end
        return melts
    end
    export melts_query

    """
    ```julia
    melts_query_modes(scratchdir::String; index=1)
    ```
    Read modal phase proportions from `Phase_mass_tbl.txt` in specified MELTS run
    Returns an elementified dictionary
    """
    function melts_query_modes(scratchdir::String; index=1, importas=:Dict)
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Read results and return them if possible
        if isfile(prefix*"/Phase_mass_tbl.txt")
            # Read data as an Array{Any}
            data = readdlm(prefix*"Phase_mass_tbl.txt", ' ', skipstart=1)
            # Convert to a dictionary
            data = elementify(data, standardize=true, skipnameless=true, importas=importas)
        else
            # Return empty dictionary if file doesn't exist
            data = importas==:Dict ? Dict() : ()
        end
        return data
    end
    export melts_query_modes

    """
    ```julia
    melts_clean_modes(scratchdir::String; index=1)
    ```
    Read and parse / clean-up modal phase proportions from specified MELTS run directory
    Returns an elementified dictionary
    """
    function melts_clean_modes(scratchdir::String; index=1)
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Read results and return them if possible
        if isfile(prefix*"/Phase_mass_tbl.txt")
            # Read data as an Array{Any}
            data = readdlm(prefix*"Phase_mass_tbl.txt", ' ', skipstart=1)
            # Convert to a dictionary
            data = elementify(data, standardize=true, skipnameless=true, importas=:Dict)

            # Start by transferring over all the non-redundant elements
            modes = typeof(data)()
            for e in data["elements"]
                m = replace(e, r"_.*" => s"")
                if haskey(modes, m)
                    modes[m] .+= data[e]
                else
                    modes[m] = copy(data[e])
                end
            end

            # Add the sum of all solids
            modes["solids"] = zeros(size(data["Temperature"]))
            for e in data["elements"][4:end]
                if !contains(e, "water") && !contains(e, "liquid")
                    modes["solids"] .+= data[e]
                end
            end

            # Get full mineral compositions, add feldspar and oxides
            melts = melts_query(scratchdir, index=index)
            if containsi(melts["minerals"],"feldspar")
                modes["anorthite"] = zeros(size(modes["Temperature"]))
                modes["albite"] = zeros(size(modes["Temperature"]))
                modes["orthoclase"] = zeros(size(modes["Temperature"]))
            end
            An_Ca = (238.12507+40.0784) / (15.999+40.0784)
            Ab_Na = (239.22853+22.98977*2) / (15.999+22.98977*2)
            Or_K  = (239.22853+39.09831*2) / (15.999+39.09831*2)
            if containsi(melts["minerals"],"rhm_oxide")
                modes["ilmenite"] = zeros(size(modes["Temperature"]))
                modes["magnetite"] = zeros(size(modes["Temperature"]))
                modes["hematite"] = zeros(size(modes["Temperature"]))
            end
            for m in melts["minerals"]
                if containsi(m,"feldspar")
                    t = vec(findclosest(melts[m]["Temperature"],modes["Temperature"]))
                    AnAbOr = [melts[m]["CaO"]*An_Ca melts[m]["Na2O"]*Ab_Na melts[m]["K2O"]*Or_K] |> x -> x ./ sum(x, dims=2)
                    modes["anorthite"][t] .+= AnAbOr[:,1] .*  melts[m]["mass"]
                    modes["albite"][t] .+= AnAbOr[:,2] .*  melts[m]["mass"]
                    modes["orthoclase"][t] .+= AnAbOr[:,3] .*  melts[m]["mass"]
                elseif containsi(m,"rhm_oxide")
                    t = vec(findclosest(melts[m]["Temperature"],modes["Temperature"]))
                    Ilmenite = Vector{Float64}(undef, length(t))
                    Magnetite = Vector{Float64}(undef, length(t))
                    if  haskey(melts[m],"MnO")
                        Ilmenite .= (melts[m]["TiO2"] + melts[m]["MnO"]+(melts[m]["TiO2"]*(71.8444/79.8768) - melts[m]["MnO"]*(71.8444/70.9374))) / 100
                        Magnetite .= (melts[m]["FeO"] - (melts[m]["TiO2"])*71.8444/79.8768) * (1+159.6882/71.8444)/100
                    else
                        Ilmenite .= (melts[m]["TiO2"] + melts[m]["TiO2"]*71.8444/79.8768) / 100
                        Magnetite .= (melts[m]["FeO"] - melts[m]["TiO2"]*71.8444/79.8768) * (1+159.6882/71.8444)/100
                    end
                    Magnetite[Magnetite.<0] .= 0
                    Hematite = (melts[m]["Fe2O3"] - Magnetite*100*159.6882/231.5326)/100
                    modes["ilmenite"][t] .+= melts[m]["mass"] .* Ilmenite
                    modes["magnetite"][t] .+= melts[m]["mass"] .* Magnetite
                    modes["hematite"][t] .+= melts[m]["mass"] .* Hematite
                end
            end
            minerals = sort(collect(keys(modes)))
            modes["elements"] = ["Pressure","Temperature","mass","solids","liquid"] ∪ minerals[.!containsi.(minerals, "feldspar") .& .!containsi.(minerals, "rhm")]
        else
            # Return empty dictionary if file doesn't exist
            modes = Dict()
        end
        return modes
    end
    export melts_clean_modes

    """
    ```julia
    melts_query_liquid(scratchdir::String; index=1)
    ```
    Read liquid composition from `Liquid_comp_tbl.txt` in specified MELTS run directory
    Returns an elementified dictionary
    """
    function melts_query_liquid(scratchdir::String; index=1, importas=:Dict)
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Read results and return them if possible
        if isfile(prefix*"/Liquid_comp_tbl.txt")
            # Read data as an Array{Any}
            data = readdlm(prefix*"Liquid_comp_tbl.txt", ' ', skipstart=1)
            # Convert to a dictionary
            data = elementify(data, standardize=true, skipnameless=true, importas=importas)
        else
            # Return empty dictionary if file doesn't exist
            data = importas==:Dict ? Dict() : ()
        end
        return data
    end
    export melts_query_liquid

    """
    ```julia
    melts_query_solid(scratchdir::String; index=1)
    ```
    Read solid composition from `Solid_comp_tbl.txt` in specified MELTS run directory
    Returns an elementified dictionary
    """
    function melts_query_solid(scratchdir::String; index=1, importas=:Dict)
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Read results and return them if possible
        if isfile(prefix*"/Solid_comp_tbl.txt")
            # Read data as an Array{Any}
            data = readdlm(prefix*"Solid_comp_tbl.txt", ' ', skipstart=1)
            # Convert to a dictionary
            data = elementify(data, standardize=true, skipnameless=true, importas=importas)
        else
            # Return empty dictionary if file doesn't exist
            data = importas==:Dict ? Dict() : ()
        end
        return data
    end
    export melts_query_solid

    """
    ```julia
    melts_query_system(scratchdir::String; index=1, importas=:Dict)
    ```
    Read system thermodynamic and composition data from `System_main_tbl.txt` in
    specified MELTS run directory. Returns an elementified dictionary or tuple.
    """
    function melts_query_system(scratchdir::String; index=1, importas=:Dict)
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Read results and return them if possible
        if isfile(prefix*"/System_main_tbl.txt")
            # Read data as an Array{Any}
            data = readdlm(prefix*"System_main_tbl.txt", ' ', skipstart=1)
            # Convert to a dictionary
            data = elementify(data, standardize=true, skipnameless=true, importas=importas)
        else
            # Return empty dictionary if file doesn't exist
            data = importas==:Dict ? Dict() : ()
        end
        return data
    end
    export melts_query_system

## -- Perplex interface: 1. Configuration

    """
    ```julia
    perplex_configure_geotherm(perplexdir::String, scratchdir::String, composition::Collection{Number},
        \telements::String=["SIO2","TIO2","AL2O3","FEO","MGO","CAO","NA2O","K2O","H2O"],
        \tP_range=(280,28000), T_surf::Number=273.15, geotherm::Number=0.1;
        \tdataset::String="hp02ver.dat",
        \tindex::Integer=1,
        \tnpoints::Integer=100,
        \tsolution_phases::String="O(HP)\\nOpx(HP)\\nOmph(GHP)\\nGt(HP)\\noAmph(DP)\\ncAmph(DP)\\nT\\nB\\nChl(HP)\\nBio(TCC)\\nMica(CF)\\nCtd(HP)\\nIlHm(A)\\nSp(HP)\\nSapp(HP)\\nSt(HP)\\nfeldspar_B\\nDo(HP)\\nF\\n",
        \texcludes::String="ts\\nparg\\ngl\\nged\\nfanth\\ng\\n",
        \tmode_basis::String="vol",  #["vol", "wt", "mol"]
        \tcomposition_basis::String="wt",  #["vol", "wt", "mol"]
        \tfluid_eos::Integer=5)
    ```

    Set up a PerpleX calculation for a single bulk composition along a specified
    geothermal gradient and pressure (depth) range. P specified in bar and T_surf
    in Kelvin, with geothermal gradient in units of Kelvin/bar
    """
    function perplex_configure_geotherm(perplexdir::String, scratchdir::String, composition::Collection{Number},
            elements::Collection{String}=["SIO2","TIO2","AL2O3","FEO","MGO","CAO","NA2O","K2O","H2O"],
            P_range::NTuple{2,Number}=(280,28000), T_surf::Number=273.15, geotherm::Number=0.1;
            dataset::String="hp02ver.dat",
            index::Integer=1,
            npoints::Integer=100,
            solution_phases::String="O(HP)\nOpx(HP)\nOmph(GHP)\nGt(HP)\noAmph(DP)\ncAmph(DP)\nT\nB\nChl(HP)\nBio(TCC)\nMica(CF)\nCtd(HP)\nIlHm(A)\nSp(HP)\nSapp(HP)\nSt(HP)\nfeldspar_B\nDo(HP)\nF\n",
            excludes::String="ts\nparg\ngl\nged\nfanth\ng\n",
            mode_basis::String="vol",
            composition_basis::String="wt",
            fluid_eos::Integer=5
        )

        build = joinpath(perplexdir, "build")# path to PerpleX build
        vertex = joinpath(perplexdir, "vertex")# path to PerpleX vertex

        #Configure working directory
        prefix = joinpath(scratchdir, "out$(index)/")
        system("rm -rf $prefix; mkdir -p $prefix")

        # Place required data files
        system("cp $(joinpath(perplexdir,dataset)) $prefix")
        system("cp $(joinpath(perplexdir,"perplex_option.dat")) $prefix")
        system("cp $(joinpath(perplexdir,"solution_model.dat")) $prefix")

        # Edit perplex_option.dat to specify number of nodes at which to solve
        system("sed -e \"s/1d_path .*|/1d_path                   $npoints $npoints |/\" -i.backup $(prefix)perplex_option.dat")

        # Edit perplex_option.dat to output all seismic properties
        #println("editing perplex options ")
        system("sed -e \"s/seismic_output .*|/seismic_output                   all |/\" -i.backup $(prefix)perplex_option.dat")

        # Specify whether we want volume or weight percentages
        system("sed -e \"s/proportions .*|/proportions                    $mode_basis |/\" -i.backup $(prefix)perplex_option.dat")
        system("sed -e \"s/composition_system .*|/composition_system             $composition_basis |/\" -i.backup $(prefix)perplex_option.dat")
        system("sed -e \"s/composition_phase .*|/composition_phase              $composition_basis |/\" -i.backup $(prefix)perplex_option.dat")

        # Create build batch file.
        fp = open(prefix*"build.bat", "w")

        # Name, components, and basic options. P-T conditions.
        # default fluid_eos = 5: Holland and Powell (1998) "CORK" fluid equation of state
        elementstring = join(elements .* "\n")
        write(fp,"$index\n$dataset\nperplex_option.dat\nn\n3\nn\nn\nn\n$elementstring\n$fluid_eos\nn\ny\n2\n1\n$T_surf\n$geotherm\n$(first(P_range))\n$(last(P_range))\ny\n") # v6.8.7
        # write(fp,"$index\n$dataset\nperplex_option.dat\nn\nn\nn\nn\n$elementstring\n5\n3\nn\ny\n2\n1\n$T_surf\n$geotherm\n$(first(P_range))\n$(last(P_range))\ny\n") # v6.8.1

        # Whole-rock composition
        for i ∈ eachindex(composition)
            write(fp,"$(composition[i]) ")
        end
        # Solution model
        if length(excludes) > 0
            write(fp,"\nn\ny\nn\n$excludes\ny\nsolution_model.dat\n$solution_phases\nGeothermal")
        else
            write(fp,"\nn\nn\ny\nsolution_model.dat\n$(solution_phases)\nGeothermal")
        end
        close(fp)

        # build PerpleX problem definition
        system("cd $prefix; $build < build.bat > build.log")

        println("Built problem definition")

        # Run PerpleX vertex calculations
        result = system("cd $prefix; echo $index | $vertex > vertex.log")
        return result
    end
    export perplex_configure_geotherm

    """
    ```julia
    perplex_configure_isobar(perplexdir::String, scratchdir::String, composition::Collection{Number},
        \telements::String=["SIO2","TIO2","AL2O3","FEO","MGO","CAO","NA2O","K2O","H2O"]
        \tP::Number=10000, T_range::NTuple{2,Number}=(500+273.15, 1500+273.15);
        \tdataset::String="hp11ver.dat",
        \tindex::Integer=1,
        \tnpoints::Integer=100,
        \tsolution_phases::String="O(HP)\\nOpx(HP)\\nOmph(GHP)\\nGt(HP)\\noAmph(DP)\\ncAmph(DP)\\nT\\nB\\nChl(HP)\\nBio(TCC)\\nMica(CF)\\nCtd(HP)\\nIlHm(A)\\nSp(HP)\\nSapp(HP)\\nSt(HP)\\nfeldspar_B\\nDo(HP)\\nF\\n",
        \texcludes::String="ts\\nparg\\ngl\\nged\\nfanth\\ng\\n",
        \tmode_basis::String="vol",  #["vol", "wt", "mol"]
        \tcomposition_basis::String="wt",  #["vol", "wt", "mol"]
        \tnonlinear_subdivision::Bool=false,
        \tfluid_eos::Integer=5)
    ```

    Set up a PerpleX calculation for a single bulk composition along a specified
    isobaric temperature gradient. P specified in bar and T_range in Kelvin
    """
    function perplex_configure_isobar(perplexdir::String, scratchdir::String, composition::Collection{Number},
            elements::Collection{String}=("SIO2","TIO2","AL2O3","FEO","MGO","CAO","NA2O","K2O","H2O"),
            P::Number=10000, T_range::NTuple{2,Number}=(500+273.15, 1500+273.15);
            dataset::String="hp11ver.dat",
            index::Integer=1,
            npoints::Integer=100,
            solution_phases::String="O(HP)\nOpx(HP)\nOmph(GHP)\nGt(HP)\noAmph(DP)\ncAmph(DP)\nT\nB\nChl(HP)\nBio(TCC)\nMica(CF)\nCtd(HP)\nIlHm(A)\nSp(HP)\nSapp(HP)\nSt(HP)\nfeldspar_B\nDo(HP)\nF\n",
            excludes::String="ts\nparg\ngl\nged\nfanth\ng\n",
            mode_basis::String="wt",
            composition_basis::String="wt",
            nonlinear_subdivision::Bool=false,
            fluid_eos::Integer=5
        )

        build = joinpath(perplexdir, "build")# path to PerpleX build
        vertex = joinpath(perplexdir, "vertex")# path to PerpleX vertex

        #Configure working directory
        prefix = joinpath(scratchdir, "out$(index)/")
        system("rm -rf $prefix; mkdir -p $prefix")

        # Place required data files
        system("cp $(joinpath(perplexdir,dataset)) $prefix")
        system("cp $(joinpath(perplexdir,"perplex_option.dat")) $prefix")
        system("cp $(joinpath(perplexdir,"solution_model.dat")) $prefix")

        # Edit perplex_option.dat to specify number of nodes at which to solve
        system("sed -e \"s/1d_path .*|/1d_path                   $npoints $npoints |/\" -i.backup $(prefix)perplex_option.dat")

        # Specify whether we want volume or weight percentages
        system("sed -e \"s/proportions .*|/proportions                    $mode_basis |/\" -i.backup $(prefix)perplex_option.dat")
        system("sed -e \"s/composition_system .*|/composition_system             $composition_basis |/\" -i.backup $(prefix)perplex_option.dat")
        system("sed -e \"s/composition_phase .*|/composition_phase              $composition_basis |/\" -i.backup $(prefix)perplex_option.dat")

        # Turn on nonlinear subdivision and change resolution
        if nonlinear_subdivision
            system("sed -e \"s/non_linear_switch .*|/non_linear_switch              T |/\" -i.backup $(prefix)perplex_option.dat")
            system("sed -e \"s:initial_resolution .*|:initial_resolution        1/2 1/4 |:\" -i.backup $(prefix)perplex_option.dat")
        end

        # Create build batch file
        # Options based on Perplex v6.8.7
        fp = open(prefix*"build.bat", "w")

        # Name, components, and basic options. P-T conditions.
        # default fluid_eos = 5: Holland and Powell (1998) "CORK" fluid equation of state
        elementstring = join(elements .* "\n")
        write(fp,"$index\n$dataset\nperplex_option.dat\nn\n3\nn\nn\nn\n$elementstring\n$fluid_eos\nn\nn\n2\n$(first(T_range))\n$(last(T_range))\n$P\ny\n") # v6.8.7
        # write(fp,"$index\n$dataset\nperplex_option.dat\nn\nn\nn\nn\n$elementstring\n$fluid_eos\n3\nn\nn\n2\n$(first(T_range))\n$(last(T_range))\n$P\ny\n") # v6.8.1

        # Whole-rock composition
        for i ∈ eachindex(composition)
            write(fp,"$(composition[i]) ")
        end
        # Solution model
        write(fp,"\nn\ny\nn\n$excludes\ny\nsolution_model.dat\n$solution_phases\nIsobaric")
        close(fp)

        # build PerpleX problem definition
        system("cd $prefix; $build < build.bat > build.log")

        # Run PerpleX vertex calculations
        result = system("cd $prefix; printf \"$index\ny\ny\ny\ny\ny\ny\ny\ny\n\" | $vertex > vertex.log")
        return result
    end
    export perplex_configure_isobar

    """
    ```julia
    perplex_configure_path(perplexdir::String, scratchdir::String, composition::Collection{Number}, PTdir::String="", PTfilename::String="",
        \telements::String=("SIO2","TIO2","AL2O3","FEO","MGO","CAO","NA2O","K2O","H2O"),
        \tT_range::NTuple{2,Number}=(500+273.15, 1050+273.15);
        \tdataset::String="hp11ver.dat",
        \tindex::Integer=1,
        \tsolution_phases::String="O(HP)\\nOpx(HP)\\nOmph(GHP)\\nGt(HP)\\noAmph(DP)\\ncAmph(DP)\\nT\\nB\\nChl(HP)\\nBio(TCC)\\nMica(CF)\\nCtd(HP)\\nIlHm(A)\\nSp(HP)\\nSapp(HP)\\nSt(HP)\\nfeldspar_B\\nDo(HP)\\nF\\n",
        \texcludes::String="ts\\nparg\\ngl\\nged\\nfanth\\ng\\n",
        \tmode_basis::String="wt",  #["vol", "wt", "mol"]
        \tcomposition_basis::String="wt",  #["vol", "wt", "mol"]
        \tnonlinear_subdivision::Bool=false,
        \tfluid_eos::Integer=5)
    ```

    Set up a PerpleX calculation for a single bulk composition along a specified
    pressure–temperature path with T as the independent variable. 
    
    P specified in bar and T_range in Kelvin
    """
    function perplex_configure_path(perplexdir::String, scratchdir::String, composition::Collection{Number}, PTdir::String="", PTfilename = "",
        elements::Collection{String}=("SIO2","TIO2","AL2O3","FEO","MGO","CAO","NA2O","K2O","H2O"),
        T_range::NTuple{2,Number}=(500+273.15, 1050+273.15);
        dataset::String="hp11ver.dat",
        index::Integer=1,
        solution_phases::String="O(HP)\\nOpx(HP)\\nOmph(GHP)\\nGt(HP)\\noAmph(DP)\\ncAmph(DP)\\nT\\nB\\nChl(HP)\\nBio(TCC)\\nMica(CF)\\nCtd(HP)\\nIlHm(A)\\nSp(HP)\\nSapp(HP)\\nSt(HP)\\nfeldspar_B\\nDo(HP)\\nF\\n",
        excludes::String="ts\\nparg\\ngl\\nged\\nfanth\\ng\\n",
        mode_basis::String="wt",  #["vol", "wt", "mol"]
        composition_basis::String="wt",  #["vol", "wt", "mol"]
        nonlinear_subdivision::Bool=false,
        fluid_eos::Integer=5,
        fractionate::Integer=0,
        )

        build = joinpath(perplexdir, "build")# path to PerpleX build
        vertex = joinpath(perplexdir, "vertex")# path to PerpleX vertex

        # Configure working directory
        prefix = joinpath(scratchdir, "out$(index)/")
        system("rm -rf $prefix; mkdir -p $prefix")

        # Place required data files
        system("cp $(joinpath(perplexdir, dataset)) $prefix")
        system("cp $(joinpath(perplexdir,"perplex_option.dat")) $prefix")
        system("cp $(joinpath(perplexdir,"solution_model.dat")) $prefix")
        

        # Specify whether we want volume or weight percentages
        system("sed -e \"s/proportions .*|/proportions                    $mode_basis |/\" -i.backup $(prefix)perplex_option.dat")
        system("sed -e \"s/composition_system .*|/composition_system             $composition_basis |/\" -i.backup $(prefix)perplex_option.dat")
        system("sed -e \"s/composition_phase .*|/composition_phase              $composition_basis |/\" -i.backup $(prefix)perplex_option.dat")
        
        # Turn on nonlinear subdivision and change resolution
        if nonlinear_subdivision
            system("sed -e \"s/non_linear_switch .*|/non_linear_switch              T |/\" -i.backup $(prefix)perplex_option.dat")
            system("sed -e \"s:initial_resolution .*|:initial_resolution        1/2 1/4 |:\" -i.backup $(prefix)perplex_option.dat")
        end

        # Create default P–T.dat path if one is not provided
        if PTdir == ""
            # Input parameters
            P_range = (2000, 6000, 10000, 14000, 18000) #bar
            T_range = (550+273.15, 1050+273.15) #K
            T_int = 10 #Interval for T 

            T = T_range[1]:T_int:T_range[2]
            P = zeros(length(T))

            for i in 1:length(T)
                if i == length(T)
                    P[i] = P_range[end]
                else
                    P[i] = P_range[floor(Int64, (i/length(T)) * length(P_range) + 1)]
                end 
            end

            PTfile = joinpath(prefix, "P–T.dat")
            # PTdir = "P–T.dat"
            # Save P–T path as .dat file
            # Apparently you need to have it as T and then P despite what Perplex tells you
            open(PTfile, "w") do file
                for i in zip(T, P)
                    write(file, "$(i[1])\t$(i[2])\n")
                end
            end

            system("cp $(PTfile) $perplexdir")
            system("cp $(PTfile) $prefix")
            PTfilename = "P–T.dat"
        else 
            system("cp $(PTdir) $prefix")
        end

        # Create build batch file
        fp = open(prefix*"build.bat", "w")

        # Name, components, and basic options. P-T conditions.
        # default fluid_eos = 5: Holland and Powell (1998) "CORK" fluid equation of state
        elementstring = join(elements .* "\n")

        write(fp,"$index\n$dataset\nperplex_option.dat\nn\n3\nn\nn\nn\n$elementstring\ny\n$PTfilename\n2\n$(first(T_range)) $(last(T_range))\ny\n") #stable
        # write(fp,"$index\n$dataset\nperplex_option.dat\nn\n3\nn\nn\nn\n$elementstring\n$fluid_eos\ny\n$PTfilename\n2\ny\n") #6.8.7

        # Whole-rock composition
        for i ∈ eachindex(composition)
            write(fp,"$(composition[i]) ")
        end

        # Solution model
        write(fp,"\nn\ny\nn\n$excludes\ny\nsolution_model.dat\n$solution_phases\nP-T Path")
        close(fp)

        # build PerpleX problem definition
        system("cd $prefix; $build < build.bat > build.log")

        # Run PerpleX vertex calculations
        result = system("cd $prefix; printf \"$index\n$fractionate\n\" | $vertex > vertex.log")
        return result
    end
    export perplex_configure_path

    """
    ```julia
    perplex_configure_pseudosection(perplexdir::String, scratchdir::String, composition::Collection{Number},
        \telements::Collection{String}=("SIO2","TIO2","AL2O3","FEO","MGO","CAO","NA2O","K2O","H2O"),
        \tP::NTuple{2,Number}=(280, 28000), T::NTuple{2,Number}=(273.15, 1500+273.15);
        \tdataset::String="hp11ver.dat",
        \tindex::Integer=1,
        \txnodes::Integer=42,
        \tynodes::Integer=42,
        \tsolution_phases::String="O(HP)\\nOpx(HP)\\nOmph(GHP)\\nGt(HP)\\noAmph(DP)\\ncAmph(DP)\\nT\\nB\\nChl(HP)\\nBio(TCC)\\nMica(CF)\\nCtd(HP)\\nIlHm(A)\\nSp(HP)\\nSapp(HP)\\nSt(HP)\\nfeldspar_B\\nDo(HP)\\nF\\n",
        \texcludes::String="ts\\nparg\\ngl\\nged\\nfanth\\ng\\n",
        \tmode_basis::String="vol", #["vol", "wt", "mol"]
        \tcomposition_basis::String="wt", #["wt", "mol"]
        \tfluid_eos::Number=5)
    ```

    Set up a PerpleX calculation for a single bulk composition across an entire
    2d P-T space. P specified in bar and T in Kelvin.
    """
    function perplex_configure_pseudosection(perplexdir::String, scratchdir::String, composition::Collection{Number},
            elements::Collection{String}=("SIO2","TIO2","AL2O3","FEO","MGO","CAO","NA2O","K2O","H2O"),
            P::NTuple{2,Number}=(280, 28000), T::NTuple{2,Number}=(273.15, 1500+273.15);
            dataset::String="hp11ver.dat",
            index::Integer=1,
            xnodes::Integer=42,
            ynodes::Integer=42,
            solution_phases::String="O(HP)\nOpx(HP)\nOmph(GHP)\nGt(HP)\noAmph(DP)\ncAmph(DP)\nT\nB\nChl(HP)\nBio(TCC)\nMica(CF)\nCtd(HP)\nIlHm(A)\nSp(HP)\nSapp(HP)\nSt(HP)\nfeldspar_B\nDo(HP)\nF\n",
            excludes::String="ts\nparg\ngl\nged\nfanth\ng\n",
            mode_basis::String="vol",
            composition_basis::String="wt",
            fluid_eos::Number=5
        )

        build = joinpath(perplexdir, "build")# path to PerpleX build
        vertex = joinpath(perplexdir, "vertex")# path to PerpleX vertex

        #Configure working directory
        prefix = joinpath(scratchdir, "out$(index)/")
        system("rm -rf $prefix; mkdir -p $prefix")

        # Place required data files
        system("cp $(joinpath(perplexdir,dataset)) $prefix")
        system("cp $(joinpath(perplexdir,"perplex_option.dat")) $prefix")
        system("cp $(joinpath(perplexdir,"solution_model.dat")) $prefix")

        # Edit data files to specify number of nodes at which to solve
        system("sed -e \"s/x_nodes .*|/x_nodes                   $xnodes $xnodes |/\" -i.backup $(prefix)perplex_option.dat")
        system("sed -e \"s/y_nodes .*|/y_nodes                   $ynodes $ynodes |/\" -i.backup $(prefix)perplex_option.dat")

        # Specify whether we want volume or weight percentages
        system("sed -e \"s/proportions .*|/proportions                    $mode_basis |/\" -i.backup $(prefix)perplex_option.dat")
        system("sed -e \"s/composition_system .*|/composition_system             $composition_basis |/\" -i.backup $(prefix)perplex_option.dat")
        system("sed -e \"s/composition_phase .*|/composition_phase              $composition_basis |/\" -i.backup $(prefix)perplex_option.dat")

        # Create build batch file
        # Options based on Perplex v6.8.7
        fp = open(prefix*"build.bat", "w")

        # Name, components, and basic options. P-T conditions.
        # default fluid_eos = 5: Holland and Powell (1998) "CORK" fluid equation of state
        elementstring = join(elements .* "\n")
        write(fp,"$index\n$dataset\nperplex_option.dat\nn\n2\nn\nn\nn\n$elementstring\n$fluid_eos\nn\n2\n$(first(T))\n$(last(T))\n$(first(P))\n$(last(P))\ny\n") # v6.8.7

        # Whole-rock composition
        for i ∈ eachindex(composition)
            write(fp,"$(composition[i]) ")
        end
        # Solution model
        write(fp,"\nn\ny\nn\n$excludes\ny\nsolution_model.dat\n$solution_phases\nPseudosection")
        close(fp)

        # build PerpleX problem definition
        system("cd $prefix; $build < build.bat > build.log")

        # Run PerpleX vertex calculations
        result = system("cd $prefix; echo $index | $vertex > vertex.log")
        return result
    end
    export perplex_configure_pseudosection

## -- Perplex interface: 2. 0d queries

    """
    ```julia
    perplex_query_point(perplexdir::String, scratchdir::String, indvar::Number; index::Integer=1)
    ```

    Query perplex results at a single temperature on an isobar or single pressure
    on a geotherm. Results are returned as a string.
    """
    function perplex_query_point(perplexdir::String, scratchdir::String, indvar::Number; index::Integer=1)
        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Sanitize T inputs to avoid PerpleX escape sequence
        if indvar == 999
            indvar = 999.001
        end

        # Create werami batch file
        # Options based on Perplex v6.7.2
        fp = open(prefix*"werami.bat", "w")
        write(fp,"$index\n1\n$indvar\n999\n0\n")
        close(fp)

        # Make sure there isn"t already an output
        system("rm -f $(prefix)$(index)_1.txt")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Read results and return them if possible
        data = ""
        try
            # Read entire output file as a string
            fp = open("$(prefix)$(index)_1.txt", "r")
            data = read(fp, String)
            close(fp)
        catch
            # Return empty string if file doesn't exist
            @warn "$(prefix)$(index)_1.txt could not be parsed, perplex may not have run"

        end
        return data
    end
    """
    ```julia
    perplex_query_point(perplexdir::String, scratchdir::String, P::Number, T::Number; index::Integer=1)
    ```

    Query perplex results at a single P,T point in a pseudosection.
    Results are returned as a string.
    """
    function perplex_query_point(perplexdir::String, scratchdir::String, P::Number, T::Number; index::Integer=1)
        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Sanitize T inputs to avoid PerpleX escape sequence
        if P == 99
            P = 99.001
        end
        if T == 99
            T = 99.001
        end

        # Create werami batch file
        # Options based on Perplex v6.7.2
        fp = open(prefix*"werami.bat", "w")
        write(fp,"$index\n1\n$T\n$P\n99\n99\n0\n")
        close(fp)

        # Make sure there isn"t already an output
        system("rm -f $(prefix)$(index)_1.txt")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Read results and return them if possible
        data = ""
        try
            # Read entire output file as a string
            fp = open("$(prefix)$(index)_1.txt", "r")
            data = read(fp, String)
            close(fp)
        catch
            # Return empty string if file doesn't exist
            @warn "$(prefix)$(index)_1.txt could not be parsed, perplex may not have run"

        end
        return data
    end
    export perplex_query_point

## --- Perplex interface: 3. 1d queries

    # # We'll need this for when perplex messes up
    # molarmass = Dict("SIO2"=>60.083, "TIO2"=>79.8651, "AL2O3"=>101.96007714, "FE2O3"=>159.6874, "FEO"=>71.8442, "MGO"=>40.304, "CAO"=>56.0774, "MNO"=>70.9370443, "NA2O"=>61.978538564, "K2O"=>94.19562, "H2O"=>18.015, "CO2"=>44.009, "P2O5"=>141.942523997)

    """
    ```julia
    perplex_query_seismic(perplexdir::String, scratchdir::String;
        \tdof::Integer=1, index::Integer=1, include_fluid="n")
    ```

    Query perplex seismic results along a previously configured 1-d path (dof=1,
    isobar or geotherm) or 2-d grid / pseudosection (dof=2).
    Results are returned as a dictionary.
    """
    function perplex_query_seismic(perplexdir::String, scratchdir::String;
        dof::Integer=1, index::Integer=1, include_fluid::String="n", importas=:Dict)
        # Query a pre-defined path (isobar or geotherm)

        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Create werami batch file
        fp = open(prefix*"werami.bat", "w")
        if dof == 1
            # v6.7.8 1d path
            write(fp,"$index\n3\n2\nn\n$include_fluid\n13\nn\n$include_fluid\n15\nn\n$include_fluid\n0\n0\n")
        elseif dof == 2
            # v6.7.8 2d grid
            write(fp,"$index\n2\n2\nn\n$include_fluid\n13\nn\n$include_fluid\n15\nn\n$include_fluid\n0\nn\n1\n0\n")
        else
            error("Expecting dof = 1 (path) or 2 (grid/pseudosection) degrees of freedom")
        end
        close(fp)

        # Make sure there isn"t already an output
        system("rm -f $(prefix)$(index)_1.tab")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Ignore initial and trailing whitespace
        system("sed -e \"s/^  *//\" -e \"s/  *\$//\" -i.backup $(prefix)$(index)_1.tab")
        # Merge delimiters
        system("sed -e \"s/  */ /g\" -i.backup $(prefix)$(index)_1.tab")

        # Read results and return them if possible
        data = nothing
        try
            # Read data as an Array{Any}
            data = readdlm("$(prefix)$(index)_1.tab", ' ', skipstart=8)
            # Convert to a dictionary
            data = elementify(data, importas=importas)
        catch
            # Return empty dictionary if file doesn't exist
            data = importas==:Dict ? Dict() : ()
        end
        return data
    end
    """
    ```julia
    perplex_query_seismic(perplexdir::String, scratchdir::String, P::NTuple{2,Number}, T::NTuple{2,Number};
        \tindex::Integer=1, npoints::Integer=200, include_fluid="n")
    ```

    Query perplex seismic results along a specified P-T path using a pre-computed
    pseudosection. Results are returned as a dictionary.
    """
    function perplex_query_seismic(perplexdir::String, scratchdir::String, P::NTuple{2,Number}, T::NTuple{2,Number};
        index::Integer=1, npoints::Integer=200, include_fluid="n", importas=:Dict)
        # Query a new path from a pseudosection

        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Create werami batch file
        fp = open(prefix*"werami.bat", "w")
        # v6.7.8 pseudosection
        write(fp,"$index\n3\nn\n$(first(T))\n$(first(P))\n$(last(T))\n$(last(P))\n$npoints\n2\nn
                $include_fluid\n13\nn\n$include_fluid\n15\nn\n$include_fluid\n0\n0\n")
        close(fp)

        # Make sure there isn"t already an output
        system("rm -f $(prefix)$(index)_1.tab")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Ignore initial and trailing whitespace
        system("sed -e \"s/^  *//\" -e \"s/  *\$//\" -i.backup $(prefix)$(index)_1.tab")
        # Merge delimiters
        system("sed -e \"s/  */ /g\" -i.backup $(prefix)$(index)_1.tab")

        # Read results and return them if possible
        data = nothing
        try
            # Read data as an Array{Any}
            data = readdlm("$(prefix)$(index)_1.tab", ' ', skipstart=8)
            # Convert to a dictionary
            data = elementify(data, importas=importas)
        catch
            # Return empty dictionary if file doesn't exist
            data = importas==:Dict ? Dict() : ()
        end
        return data
    end
    function perplex_query_seismic(perplexdir::String, scratchdir::String, P::AbstractArray, T::AbstractArray;
        index::Integer=1, include_fluid="n", importas=:Dict)
        # Query a new path from a pseudosection

        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Write TP data to file
        fp = open(prefix*"TP.tsv", "w")
        for i in eachindex(T,P)
            write(fp,"$(T[i])\t$(P[i])\n")
        end
        close(fp)

        # Create werami batch file
        fp = open(prefix*"werami.bat", "w")
        # v6.7.8 pseudosection
        write(fp,"$index\n4\n2\nTP.tsv\n1\n2\nn\n$include_fluid
                    13\nn\n$include_fluid\n15\nn\n$include_fluid\n0\n0\n")
        close(fp)

        # Make sure there isn"t already an output
        system("rm -f $(prefix)$(index)_1.tab")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Ignore initial and trailing whitespace
        system("sed -e \"s/^  *//\" -e \"s/  *\$//\" -i.backup $(prefix)$(index)_1.tab")
        # Merge delimiters
        system("sed -e \"s/  */ /g\" -i.backup $(prefix)$(index)_1.tab")

        # Read results and return them if possible
        data = nothing
        try
            # Read data as an Array{Any}
            data = readdlm("$(prefix)$(index)_1.tab", ' ', skipstart=8)
            # Convert to a dictionary
            data = elementify(data, importas=importas)
        catch
            # Return empty dictionary if file doesn't exist
            data = importas==:Dict ? Dict() : ()
        end
        return data
    end
    export perplex_query_seismic


    """
    ```julia
    perplex_query_phase(perplexdir::String, scratchdir::String, phase::String;
        \tdof::Integer=1, index::Integer=1, include_fluid="y", clean_units::Bool=true)
    ```

    Query all perplex-calculated properties for a specified phase (e.g. "Melt(G)")
    along a previously configured 1-d path (dof=1, isobar, geotherm, or P–T path) or 2-d
    grid / pseudosection (dof=2). Results are returned as a dictionary.
    """
    function perplex_query_phase(perplexdir::String, scratchdir::String, phase::String;
        dof::Integer=1, index::Integer=1, include_fluid="y", clean_units::Bool=true, importas=:Dict)
        # Query a pre-defined path (isobar or geotherm)

        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Create werami batch file
        fp = open(prefix*"werami.bat", "w")
        if dof == 1
            # v6.7.8, 1d path
            write(fp,"$index\n3\n36\n2\n$phase\n$include_fluid\n5\n0\n")
            # If a named phase (e.g. feldspar) has multiple immiscible phases, average them (5)
        elseif dof == 2
            # v6.7.8, 2d grid
            write(fp,"$index\n2\n36\n2\n$phase\n$include_fluid\nn\n1\n0\n") # v6.7.8
        else
            error("Expecting dof = 1 (path) or 2 (grid/pseudosection) degrees of freedom")
        end
        close(fp)

        # Make sure there isn"t already an output
        system("rm -f $(prefix)$(index)_1.tab*")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Ignore initial and trailing whitespace
        system("sed -e \"s/^  *//\" -e \"s/  *\$//\" -i.backup $(prefix)$(index)_1.tab")
        # Merge delimiters
        system("sed -e \"s/  */ /g\" -i.backup $(prefix)$(index)_1.tab")

        # Read results and return them if possible
        result = importas==:Dict ? Dict() : ()
        try
            # Read data as an Array{Any}
            data = readdlm("$(prefix)$(index)_1.tab", ' ', skipstart=8)
            elements = data[1,:]

            # Renormalize weight percentages
            t = contains.(elements,"wt%")
            total_weight = nansum(Float64.(data[2:end,t]),dim=2)
            # Check if perplex is messing up and outputting mole proportions
            if nanmean(total_weight) < 50
                @warn "Perplex seems to be reporting mole fractions instead of weight percentages"
                # Attempt to change back to weight percentages
                # for col = findall(t)
                #     data[2:end,col] .*= molarmass[replace(elements[col], ",wt%" => "")]
                # end
                # total_weight = nansum(Float64.(data[2:end,t]),dim=2)
            end
            data[2:end,t] .*= 100 ./ total_weight

            # Clean up element names
            if clean_units
                elements = elements .|> x -> replace(x, ",%" => "_pct") # substutue _pct for ,% in column names
                elements = elements .|> x -> replace(x, ",wt%" => "") # Remove units on major oxides
            end

            # Convert to a dictionary
            result = elementify(data,elements, skipstart=1,importas=importas)
        catch
            # Return empty dictionary if file doesn't exist
            @warn "$(prefix)$(index)_1.tab could not be parsed, perplex may not have run"
        end
        return result
    end
    """
    ```julia
    perplex_query_phase(perplexdir::String, scratchdir::String, phase::String, P::NTuple{2,Number}, T::NTuple{2,Number};
        \tindex::Integer=1, npoints::Integer=200, include_fluid="y", clean_units::Bool=true)
    ```

    Query all perplex-calculated properties for a specified phase (e.g. "Melt(G)")
    along a specified P-T path using a pre-computed pseudosection. Results are
    returned as a dictionary.
    """
    function perplex_query_phase(perplexdir::String, scratchdir::String, phase::String, P::NTuple{2,Number}, T::NTuple{2,Number};
        index::Integer=1, npoints::Integer=200, include_fluid="y", clean_units::Bool=true, importas=:Dict)
        # Query a new path from a pseudosection

        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Create werami batch file
        fp = open(prefix*"werami.bat", "w")
        # v6.7.8 pseudosection
        # If a named phase (e.g. feldspar) has multiple immiscible phases, average them (5)
        write(fp,"$index\n3\nn\n$(first(T))\n$(first(P))\n$(last(T))\n$(last(P))\n$npoints\n36\n2\n$phase\n$include_fluid\n5\n0\n")
        close(fp)

        # Make sure there isn"t already an output
        system("rm -f $(prefix)$(index)_1.tab*")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Ignore initial and trailing whitespace
        system("sed -e \"s/^  *//\" -e \"s/  *\$//\" -i.backup $(prefix)$(index)_1.tab")
        # Merge delimiters
        system("sed -e \"s/  */ /g\" -i.backup $(prefix)$(index)_1.tab")

        # Read results and return them if possible
        result = importas==:Dict ? Dict() : ()
        try
            # Read data as an Array{Any}
            data = readdlm("$(prefix)$(index)_1.tab", ' ', skipstart=8)
            elements = data[1,:]

            # Renormalize weight percentages
            t = contains.(elements,"wt%")
            total_weight = nansum(Float64.(data[2:end,t]),dim=2)
            # Check if perplex is messing up and outputting mole proportions
            if nanmean(total_weight) < 50
                @warn "Perplex seems to be reporting mole fractions instead of weight percentages"
                # , attempting to correct
                # for col = findall(t)
                #     data[2:end,col] .*= molarmass[replace(elements[col], ",wt%" => "")]
                # end
                # total_weight = nansum(Float64.(data[2:end,t]),dim=2)
            end
            data[2:end,t] .*= 100 ./ total_weight

            # Clean up element names
            if clean_units
                elements = elements .|> x -> replace(x, ",%" => "_pct") # substutue _pct for ,% in column names
                elements = elements .|> x -> replace(x, ",wt%" => "") # Remove units on major oxides
            end

            # Convert to a dictionary
            result = elementify(data,elements, skipstart=1,importas=importas)
        catch
            # Return empty dictionary if file doesn't exist
            @warn "$(prefix)$(index)_1.tab could not be parsed, perplex may not have run"
        end
        return result
    end
    function perplex_query_phase(perplexdir::String, scratchdir::String, phase::String, P::AbstractArray, T::AbstractArray;
        index::Integer=1, include_fluid="y", clean_units::Bool=true, importas=:Dict)
        # Query a new path from a pseudosection

        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Write TP data to file
        fp = open(prefix*"TP.tsv", "w")
        for i in eachindex(T,P)
            write(fp,"$(T[i])\t$(P[i])\n")
        end
        close(fp)

        # Create werami batch file
        fp = open(prefix*"werami.bat", "w")
        # v6.7.8 pseudosection
        # If a named phase (e.g. feldspar) has multiple immiscible phases, average them (5)
        write(fp,"$index\n4\n2\nTP.tsv\n1\n36\n2\n$phase\n$include_fluid\n5\n0\n")
        close(fp)

        # Make sure there isn"t already an output
        system("rm -f $(prefix)$(index)_1.tab*")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Ignore initial and trailing whitespace
        system("sed -e \"s/^  *//\" -e \"s/  *\$//\" -i.backup $(prefix)$(index)_1.tab")
        # Merge delimiters
        system("sed -e \"s/  */ /g\" -i.backup $(prefix)$(index)_1.tab")

        # Read results and return them if possible
        result = importas==:Dict ? Dict() : ()
        try
            # Read data as an Array{Any}
            data = readdlm("$(prefix)$(index)_1.tab", ' ', skipstart=8)
            elements = data[1,:]

            # Renormalize weight percentages
            t = contains.(elements,"wt%")
            total_weight = nansum(Float64.(data[2:end,t]),dim=2)
            # Check if perplex is messing up and outputting mole proportions
            if nanmean(total_weight) < 50
                @warn "Perplex seems to be reporting mole fractions instead of weight percentages"
                # , attempting to correct
                # for col = findall(t)
                #     data[2:end,col] .*= molarmass[replace(elements[col], ",wt%" => "")]
                # end
                # total_weight = nansum(Float64.(data[2:end,t]),dim=2)
            end
            data[2:end,t] .*= 100 ./ total_weight

            # Clean up element names
            if clean_units
                elements = elements .|> x -> replace(x, ",%" => "_pct") # substutue _pct for ,% in column names
                elements = elements .|> x -> replace(x, ",wt%" => "") # Remove units on major oxides
            end

            # Convert to a dictionary
            result = elementify(data,elements, skipstart=1,importas=importas)
        catch
            # Return empty dictionary if file doesn't exist
            @warn "$(prefix)$(index)_1.tab could not be parsed, perplex may not have run"
        end
        return result
    end
    export perplex_query_phase


    """
    ```julia
    perplex_query_modes(perplexdir::String, scratchdir::String;
        \tdof::Integer=1, index::Integer=1, include_fluid="y")
    ```

    Query modal mineralogy (mass proportions) along a previously configured 1-d
    path (dof=1, isobar, geotherm, or P–T path) or 2-d grid / pseudosection (dof=2).
    Results are returned as a dictionary.

    Currently returns wt% 
    """
    function perplex_query_modes(perplexdir::String, scratchdir::String;
        dof::Integer=1, index::Integer=1, include_fluid="y", importas=:Dict)
        # Query a pre-defined path (isobar or geotherm)

        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Create werami batch file
        fp = open(prefix*"werami.bat", "w")
        if dof == 1 # v6.7.8 1d path
            write(fp,"$index\n3\n38\n3\nn\n37\n0\n0\n")
        elseif dof == 2
            # v6.7.8 2d grid
            write(fp,"$index\n2\n25\nn\n$include_fluid\nn\n1\n0\n")
        else
            error("Expecting dof = 1 (path) or 2 (grid/pseudosection) degrees of freedom")
        end
        close(fp)

        # Make sure there isn"t already an output
        system("rm -f $(prefix)$(index)_1.phm*")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Ignore initial and trailing whitespace
        system("sed -e \"s/^  *//\" -e \"s/  *\$//\" -i.backup $(prefix)$(index)_1.phm")
        # Merge delimiters
        system("sed -e \"s/  */ /g\" -i.backup $(prefix)$(index)_1.phm")
        # Replace "Missing data" with just "Missing" 
        file_content = read("$(prefix)$(index)_1.phm", String)
        modified_content = replace(file_content, "Missing data" => replace("Missing data", "Missing data" => "Missing"))
        write("$(prefix)$(index)_1.phm", modified_content)

        # Read results and return them if possible
        result = importas==:Dict ? Dict() : ()
        
        if dof == 1 
            try
                # Read data as an Array{Any}
                data = readdlm("$(prefix)$(index)_1.phm", skipstart=8)
            catch
                # Return empty dictionary if file doesn't exist
                @warn "$(prefix)$(index)_1.phm could not be parsed, perplex may not have run"
            end
            # Convert to a dictionary.
            table = elementify(data, importas=importas)
            # Create results dictionary
            phase_names = unique(table["Name"])

            if haskey(table, "node#") #PT path
                nodes = unique(table["node#"])

                # Create result dictionary
                result = Dict{String, Vector{Float64}}(i => zeros(length(nodes)) for i in phase_names)
                result["P(bar)"] = zeros(length(nodes))

                # Loop through table
                for n in nodes
                    # Index table 
                    n_idx = table["node#"] .== n
                    # Index phase name and weight(kg) 
                    name = table["Name"][n_idx]
                    kg = table["phase,kg"][n_idx]
                    #  Calculate wt% and add to results dictionary
                    for i in zip(name, kg)
                        result[i[1]][floor(Int64, n)] = (i[2]/nansum(kg)) * 100
                    end
                    result["P(bar)"][floor(Int64, n)] = table["P(bar)"][n_idx][1]
                end
                result["T(K)"] = unique(table["T(K)"])
                result["node"] = nodes

            else # isobar or geotherm
                t_steps = unique(table["T(K)"])
                result = Dict{String, Vector{Float64}}(i => zeros(length(t_steps)) for i in phase_names)
                id = 1
                # Loop through table
                for t in t_steps 
                    # Index table 
                    t_idx = table["T(K)"] .== t
                    # Index phase name and weight(kg) 
                    name = table["Name"][t_idx]
                    kg = table["phase,kg"][t_idx]
                    # Calculate wt% and add to results dictionary
                    for i in zip(name, kg)
                        result[i[1]][id] = (i[2]/nansum(kg)) * 100
                    end
                    id+=1
                end
                result["T(K)"] = t_steps
            end
        else 
            # Read data as an Array{Any}
            data = readdlm("$(prefix)$(index)_1.tab", ' ', skipstart=8)
            # Convert to a dictionary.
            # Perplex sometimes returns duplicates of a single solution model, sum them.
            result = elementify(data, sumduplicates=true, importas=importas)
        end
        return result
    end
    """
    ```julia
    perplex_query_modes(perplexdir::String, scratchdir::String, P::NTuple{2,Number}, T::NTuple{2,Number};
        \tindex::Integer=1, npoints::Integer=200, include_fluid="y")
    ```

    Query modal mineralogy (mass proportions) along a specified P-T path using a
    pre-computed pseudosection. Results are returned as a dictionary.
    """
    function perplex_query_modes(perplexdir::String, scratchdir::String, P::NTuple{2,Number}, T::NTuple{2,Number};
        index::Integer=1, npoints::Integer=200, include_fluid="y", importas=:Dict)
        # Query a new path from a pseudosection

        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Create werami batch file
        fp = open(prefix*"werami.bat", "w")
        # v6.7.8 pseudosection
        write(fp,"$index\n3\nn\n$(first(T))\n$(first(P))\n$(last(T))\n$(last(P))\n$npoints\n25\nn\n$include_fluid\n0\n")
        close(fp)

        # Make sure there isn"t already an output
        system("rm -f $(prefix)$(index)_1.tab*")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Ignore initial and trailing whitespace
        system("sed -e \"s/^  *//\" -e \"s/  *\$//\" -i.backup $(prefix)$(index)_1.tab")
        # Merge delimiters
        system("sed -e \"s/  */ /g\" -i.backup $(prefix)$(index)_1.tab")

        # Read results and return them if possible
        result = importas==:Dict ? Dict() : ()
        try
            # Read data as an Array{Any}
            data = readdlm("$(prefix)$(index)_1.tab", ' ', skipstart=8)
            # Convert to a dictionary
            result = elementify(data, sumduplicates=true, importas=importas)
        catch
            # Return empty dictionary if file doesn't exist
            @warn "$(prefix)$(index)_1.tab could not be parsed, perplex may not have run"
        end
        return result
    end
    function perplex_query_modes(perplexdir::String, scratchdir::String, P::AbstractArray, T::AbstractArray;
        index::Integer=1, include_fluid="y", importas=:Dict)
        # Query a new path from a pseudosection

        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Write TP data to file
        fp = open(prefix*"TP.tsv", "w")
        for i in eachindex(T,P)
            write(fp,"$(T[i])\t$(P[i])\n")
        end
        close(fp)

        # Create werami batch file
        fp = open(prefix*"werami.bat", "w")
        # v6.7.8 pseudosection
        write(fp,"$index\n4\n2\nTP.tsv\n1\n25\nn\n$include_fluid\n0\n")
        close(fp)

        # Make sure there isn"t already an output
        system("rm -f $(prefix)$(index)_1.tab*")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Ignore initial and trailing whitespace
        system("sed -e \"s/^  *//\" -e \"s/  *\$//\" -i.backup $(prefix)$(index)_1.tab")
        # Merge delimiters
        system("sed -e \"s/  */ /g\" -i.backup $(prefix)$(index)_1.tab")

        # Read results and return them if possible
        result = importas==:Dict ? Dict() : ()
        try
            # Read data as an Array{Any}
            data = readdlm("$(prefix)$(index)_1.tab", ' ', skipstart=8)
            # Convert to a dictionary
            result = elementify(data, sumduplicates=true, importas=importas)
        catch
            # Return empty dictionary if file doesn't exist
            @warn "$(prefix)$(index)_1.tab could not be parsed, perplex may not have run"
        end
        return result
    end
    export perplex_query_modes


    """
    ```julia
    perplex_query_system(perplexdir::String, scratchdir::String;
        \tindex::Integer=1, include_fluid="y", clean_units::Bool=true)
    ```?

    Query all perplex-calculated properties for the system (with or without fluid)
    along a previously configured 1-d path (dof=1, isobar or geotherm) or 2-d
    grid / pseudosection (dof=2). Results are returned as a dictionary.
    Set include_fluid="n" to return solid+melt only.
    """
    function perplex_query_system(perplexdir::String, scratchdir::String;
        index::Integer=1, include_fluid="y", clean_units::Bool=true, dof::Integer=1, importas=:Dict)
        # Query a pre-defined path (isobar or geotherm)

        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Create werami batch file
        fp = open(prefix*"werami.bat", "w")
        if dof == 1
            # v6.7.8, 1d path
            write(fp,"$index\n3\n36\n1\n$include_fluid\n0\n")
        elseif dof == 2
            # v6.7.8, 2d grid
            write(fp,"$index\n2\n36\n1\n$include_fluid\nn\n1\n0\n")
        else
            error("Expecting dof = 1 (path) or 2 (grid/pseudosection) degrees of freedom")
        end
        close(fp)

        # Make sure there isn't already an output
        system("rm -f $(prefix)$(index)_1.tab*")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Ignore initial and trailing whitespace
        system("sed -e \"s/^  *//\" -e \"s/  *\$//\" -i.backup $(prefix)$(index)_1.tab")
        # Merge delimiters
        system("sed -e \"s/  */ /g\" -i.backup $(prefix)$(index)_1.tab")

        # Read results and return them if possible
        result = importas==:Dict ? Dict() : ()
        try
            # Read data as an Array{Any}
            data = readdlm("$(prefix)$(index)_1.tab", ' ', skipstart=8)
            elements = data[1,:]

            # Renormalize weight percentages
            t = contains.(elements,"wt%")
            total_weight = nansum(Float64.(data[2:end,t]),dim=2)
            data[2:end,t] .*= 100 ./ total_weight

            # Clean up element names
            if clean_units
                elements = elements .|> x -> replace(x, ",%" => "_pct") # substutue _pct for ,% in column names
                elements = elements .|> x -> replace(x, ",wt%" => "") # Remove units on major oxides
            end

            # Convert to a dictionary
            result = elementify(data,elements, skipstart=1,importas=importas)
        catch
            # Return empty dictionary if file doesn't exist
            @warn "$(prefix)$(index)_1.tab could not be parsed, perplex may not have run"
        end
        return result
    end
    """
    ```julia
    function perplex_query_system(perplexdir::String, scratchdir::String, P::NTuple{2,Number}, T::NTuple{2,Number};
        \tindex::Integer=1, npoints::Integer=200, include_fluid="y",clean_units::Bool=true)
    ```

    Query all perplex-calculated properties for the system (with or without fluid)
    along a specified P-T path using a pre-computed pseudosection. Results are
    returned as a dictionary. Set include_fluid="n" to return solid+melt only.
    """
    function perplex_query_system(perplexdir::String, scratchdir::String, P::NTuple{2,Number}, T::NTuple{2,Number};
        index::Integer=1, npoints::Integer=200, include_fluid="y", clean_units::Bool=true, importas=:Dict)
        # Query a new path from a pseudosection

        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Create werami batch file
        fp = open(prefix*"werami.bat", "w")
        # v6.7.8 pseudosection
        write(fp,"$index\n3\nn\n$(first(T))\n$(first(P))\n$(last(T))\n$(last(P))\n$npoints\n36\n1\n$include_fluid\n0\n")
        close(fp)

        # Make sure there isn't already an output
        system("rm -f $(prefix)$(index)_1.tab*")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Ignore initial and trailing whitespace
        system("sed -e \"s/^  *//\" -e \"s/  *\$//\" -i.backup $(prefix)$(index)_1.tab")
        # Merge delimiters
        system("sed -e \"s/  */ /g\" -i.backup $(prefix)$(index)_1.tab")

        # Read results and return them if possible
        result = importas==:Dict ? Dict() : ()
        try
            # Read data as an Array{Any}
            data = readdlm("$(prefix)$(index)_1.tab", ' ', skipstart=8)
            elements = data[1,:]

            # Renormalize weight percentages
            t = contains.(elements,"wt%")
            total_weight = nansum(Float64.(data[2:end,t]),dim=2)
            data[2:end,t] .*= 100 ./ total_weight

            # Clean up element names
            if clean_units
                elements = elements .|> x -> replace(x, ",%" => "_pct") # substutue _pct for ,% in column names
                elements = elements .|> x -> replace(x, ",wt%" => "") # Remove units on major oxides
            end

            # Convert to a dictionary
            result = elementify(data,elements, skipstart=1,importas=importas)
        catch
            # Return empty dictionary if file doesn't exist
            @warn "$(prefix)$(index)_1.tab could not be parsed, perplex may not have run"
        end
        return result
    end
    function perplex_query_system(perplexdir::String, scratchdir::String, P::AbstractArray, T::AbstractArray;
        index::Integer=1, include_fluid="y", clean_units::Bool=true, importas=:Dict)
        # Query a new path from a pseudosection

        werami = joinpath(perplexdir, "werami")# path to PerpleX werami
        prefix = joinpath(scratchdir, "out$(index)/") # path to data files

        # Write TP data to file
        fp = open(prefix*"TP.tsv", "w")
        for i in eachindex(T,P)
            write(fp,"$(T[i])\t$(P[i])\n")
        end
        close(fp)

        # Create werami batch file
        fp = open(prefix*"werami.bat", "w")
        # v6.7.8 pseudosection
        write(fp,"$index\n4\n2\nTP.tsv\n1\n36\n1\n$include_fluid\n0\n")
        close(fp)

        # Make sure there isn't already an output
        system("rm -f $(prefix)$(index)_1.tab*")

        # Extract Perplex results with werami
        system("cd $prefix; $werami < werami.bat > werami.log")

        # Ignore initial and trailing whitespace
        system("sed -e \"s/^  *//\" -e \"s/  *\$//\" -i.backup $(prefix)$(index)_1.tab")
        # Merge delimiters
        system("sed -e \"s/  */ /g\" -i.backup $(prefix)$(index)_1.tab")

        # Read results and return them if possible
        result = importas==:Dict ? Dict() : ()
        try
            # Read data as an Array{Any}
            data = readdlm("$(prefix)$(index)_1.tab", ' ', skipstart=8)
            elements = data[1,:]

            # Renormalize weight percentages
            t = contains.(elements,"wt%")
            total_weight = nansum(Float64.(data[2:end,t]),dim=2)
            data[2:end,t] .*= 100 ./ total_weight

            # Clean up element names
            if clean_units
                elements = elements .|> x -> replace(x, ",%" => "_pct") # substutue _pct for ,% in column names
                elements = elements .|> x -> replace(x, ",wt%" => "") # Remove units on major oxides
            end

            # Convert to a dictionary
            result = elementify(data,elements, skipstart=1,importas=importas)
        catch
            # Return empty dictionary if file doesn't exist
            @warn "$(prefix)$(index)_1.tab could not be parsed, perplex may not have run"
        end
        return result
    end
    export perplex_query_system

    # Translate between perplex names and germ names
    function germ_perplex_name_matches(germ_name, perplex_name)
        # Feldspar
        if germ_name == "Albite"
            any(perplex_name .== ["ab", "abh"])
        elseif germ_name == "Anorthite"
            perplex_name == "an"
        elseif germ_name == "Orthoclase"
            any(perplex_name .== ["mic", "Kf", "San", "San(TH)"])
        # Amphibole
        elseif germ_name == "Amphibole"
            any(lowercase(perplex_name) .== ["gl", "fgl", "rieb", "anth", "fanth", "cumm", "grun", "tr", "ftr", "ged", "parg", "ts"]) ||
            any(contains.(perplex_name, ["Amph", "GlTrTs", "Act(", "Anth"]))
        # Mica
        elseif germ_name == "Biotite"
            any(perplex_name .== ["ann"]) ||
            any(contains.(perplex_name, ["Bi(", "Bio("]))
        elseif germ_name == "Phlogopite"
            any(lowercase(perplex_name) .== ["naph", "phl"])
        # Pyroxene
        elseif germ_name == "Clinopyroxene"
            any(lowercase(perplex_name) .== ["di", "hed", "acm", "jd"]) ||
            any(contains.(perplex_name, ["Augite", "Cpx", "Omph"]))
        elseif germ_name == "Orthopyroxene"
            any(lowercase(perplex_name) .== ["en", "fs"]) ||
            contains(perplex_name, "Opx")
        # Cordierite
        elseif germ_name == "Cordierite"
            any(lowercase(perplex_name) .== ["crd", "fcrd", "hcrd", "mncrd"]) ||
            contains(perplex_name, "Crd")
        # Garnet
        elseif germ_name == "Garnet"
            any(lowercase(perplex_name) .== ["py", "spss", "alm", "andr", "gr"]) ||
            any(contains.(perplex_name, ["Grt", "Gt(", "Maj"]))
        # Oxides
        elseif germ_name == "Ilmenite"
            perplex_name == "ilm" || any(contains.(perplex_name, ["Ilm", "IlHm", "IlGk"]))
        elseif germ_name == "Magnetite"
            perplex_name == "mt"
        elseif germ_name == "Rutile"
            perplex_name == "ru"
        # Feldspathoids
        elseif germ_name == "Leucite"
            perplex_name == "lc"
        elseif germ_name == "Nepheline"
            perplex_name == "ne" || contains(perplex_name, "Neph")
        # Olivine
        elseif germ_name == "Olivine"
            any(lowercase(perplex_name) .== ["fo", "fa"]) ||
            any(contains.(perplex_name, ["O(", "Ol("]))
        # Spinel
        elseif germ_name == "Spinel"
            any(lowercase(perplex_name) .== ["sp", "usp"]) ||
            contains(perplex_name, "Sp(")
        # Accessories
        elseif germ_name == "Sphene"
            perplex_name == "sph"
        elseif germ_name == "Zircon"
            perplex_name == "zrc"
        elseif germ_name == "Baddeleyite"
            perplex_name == "bdy"
        else
            false
        end
    end
    export germ_perplex_name_matches

    function perplex_phase_is_fluid(phase_name)
        any(phase_name .== ["F", "WADDAH", "H2O"]) ||
        any(contains.(phase_name, ["Aq_", "F(", "Fluid"]))
    end
    export perplex_phase_is_fluid

    function perplex_phase_is_melt(phase_name)
        any(phase_name .== ["h2oL", "abL", "anL", "diL", "enL", "faL", "kspL", "qL", "silL"]) ||
        any(contains.(phase_name, ["liq", "melt", "LIQ", "MELTS"]))
    end
    export perplex_phase_is_melt

    function perplex_phase_is_solid(phase_name)
        !perplex_phase_is_fluid(phase_name) && !perplex_phase_is_melt(phase_name) &&
        !any(contains.(phase_name, ["P(", "T(", "Pressure", "Temperature", "elements", "minerals", "CO2", "Missing", "system"]))
    end
    export perplex_phase_is_solid

    function perplex_expand_name(name)
        abbreviations = ("ak", "alm", "and", "andr", "chum", "cz", "crd", "ep", "fa", "fctd", "fcrd", "fep", "fosm", "fst", "fo", "geh", "gr", "hcrd", "tpz", "ky", "larn", "law", "merw", "mctd", "mst", "mnctd", "mncrd", "mnst", "mont", "osm1", "osm2", "phA", "pump", "py", "rnk", "sill", "spss", "sph", "spu", "teph", "ty", "vsv", "zrc", "zo", "acm", "cats", "di", "en", "fs", "hed", "jd", "mgts", "pswo", "pxmn", "rhod", "wo", "anth", "cumm", "fanth", "fgl", "ftr", "ged", "gl", "grun", "parg", "rieb", "tr", "ts", "deer", "fcar", "fspr", "mcar", "spr4", "spr7", "ann", "cel", "east", "fcel", "ma", "mnbi", "mu", "naph", "pa", "phl", "afchl", "ames", "clin", "daph", "fsud", "mnchl", "sud", "atg", "chr", "fta", "kao", "pre", "prl", "ta", "tats", "ab", "anl", "an", "coe", "crst", "heu", "abh", "kals", "lmt", "lc", "me", "mic", "ne", "q", "san", "stlb", "stv", "trd", "wrk", "bdy", "cor", "geik", "hem", "herc", "ilm","oilm","lime", "mft", "mt", "mang", "bunsn", "per", "pnt", "ru", "sp", "usp", "br", "dsp", "gth", "ank", "arag", "cc", "dol", "mag", "rhc", "sid", "diam", "gph", "iron", "Ni", "CO2", "CO", "H2", "CH4", "O2", "H2O", "abL", "anL", "diL", "enL", "faL", "fliq", "foL", "h2oL", "hliq", "kspL", "mliq", "qL", "silL", "H+", "Cl-", "OH-", "Na+", "K+", "Ca++", "Mg++", "Fe++", "Al+++", "CO3", "AlOH3", "AlOH4-", "KOH", "HCL", "KCL", "NaCl", "CaCl2", "CaCl+", "MgCl2", "MgCl", "FeCl2", "aqSi",)
        full_names = ("akermanite", "almandine", "andalusite", "andradite", "clinohumite", "clinozoisite", "cordierite", "epidote(ordered)", "fayalite", "Fe-chloritoid", "Fe-cordierite", "Fe-epidote", "Fe-osumilite", "Fe-staurolite", "forsterite", "gehlenite", "grossular", "hydrous cordierite", "hydroxy-topaz", "kyanite", "larnite-bredigite", "lawsonite", "merwinite", "Mg-chloritoid", "Mg-staurolite", "Mn-chloritoid", "Mn-cordierite", "Mn-staurolite", "monticellite", "osumilite(1)", "osumilite(2)", "phase A", "pumpellyite", "pyrope", "rankinite", "sillimanite", "spessartine", "sphene", "spurrite", "tephroite", "tilleyite", "vesuvianite", "zircon", "zoisite", "acmite", "Ca-tschermaks pyroxene", "Diopside", "enstatite", "ferrosilite", "hedenbergite", "jadeite", "mg-tschermak", "pseudowollastonite", "pyroxmangite", "rhodonite", "wollastonite", "anthophyllite", "cummingtonite", "Fe-anthophyllite", "Fe-glaucophane", "ferroactinolite", "gedrite(Na-free)", "glaucophane", "grunerite", "pargasite", "riebeckite", "tremolite", "tschermakite", "deerite", "fe-carpholite", "fe-sapphirine(793)", "mg-carpholite", "sapphirine(442)", "sapphirine(793)", "annite", "celadonite", "eastonite", "Fe-celadonite", "margarite", "Mn-biotite", "muscovite", "Na-phlogopite", "paragonite", "phlogopite", "Al-free chlorite", "amesite(14Ang)", "clinochlore(ordered)", "daphnite", "Fe-sudoite", "Mn-chlorite", "Sudoite", "antigorite", "chrysotile", "Fe-talc", "Kaolinite", "prehnite", "pyrophyllite", "talc", "tschermak-talc", "albite", "analcite", "anorthite", "coesite", "cristobalite", "heulandite", "highalbite", "kalsilite", "laumontite", "leucite", "meionite", "microcline", "nepheline", "quartz", "sanidine", "stilbite", "stishovite", "tridymite", "wairakite", "baddeleyite", "corundum", "geikielite", "hematite", "hercynite", "ilmenite", "ilmenite(ordered)","lime", "magnesioferrite", "magnetite", "manganosite", "nickel oxide", "periclase", "pyrophanite", "rutile", "spinel", "ulvospinel", "brucite", "diaspore", "goethite", "ankerite", "aragonite", "calcite", "dolomite", "magnesite", "rhodochrosite", "siderite", "diamond", "graphite", "iron", "nickel", "carbon dioxide", "carbon monoxide", "hydrogen", "methane", "oxygen", "water fluid", "albite liquid", "anorthite liquid", "diopside liquid", "enstatite liquid", "fayalite liquid", "Fe-liquid (in KFMASH)", "Forsterite liquid", "H2O liquid", "H2O liquid (in KFMASH)", "K-feldspar liquid", "Mg liquid (in KFMASH)", "Silica liquid", "Sillimanite liquid", "H+(aq)", "Cl(aq)", "OH(aq)", "Na+(aq)", "K+(aq)", "Ca2+(aq)", "Mg2+(aq)", "Fe2+(aq)", "Al3+(aq)", "CO3--(aq)", "Al(OH)3(aq)", "Al(OH)4----(aq)", "KOH(aq)", "HCl(aq)", "KCl(aq)", "NaCl(aq)", "CaCl(aq)", "CaCl+(aq)", "MgCl2(aq)", "MgCl+(aq)", "FeCl(aq)", "Aqueous silica",)
        t = name .== abbreviations
        if any(t)
            full_names[findfirst(t)]
        else
            name
        end
    end
    export perplex_expand_name

    function perplex_abbreviate_name(name)
        abbreviations = ("ak", "alm", "and", "andr", "chum", "cz", "crd", "ep", "fa", "fctd", "fcrd", "fep", "fosm", "fst", "fo", "geh", "gr", "hcrd", "tpz", "ky", "larn", "law", "merw", "mctd", "mst", "mnctd", "mncrd", "mnst", "mont", "osm1", "osm2", "phA", "pump", "py", "rnk", "sill", "spss", "sph", "spu", "teph", "ty", "vsv", "zrc", "zo", "acm", "cats", "di", "en", "fs", "hed", "jd", "mgts", "pswo", "pxmn", "rhod", "wo", "anth", "cumm", "fanth", "fgl", "ftr", "ged", "gl", "grun", "parg", "rieb", "tr", "ts", "deer", "fcar", "fspr", "mcar", "spr4", "spr7", "ann", "cel", "east", "fcel", "ma", "mnbi", "mu", "naph", "pa", "phl", "afchl", "ames", "clin", "daph", "fsud", "mnchl", "sud", "atg", "chr", "fta", "kao", "pre", "prl", "ta", "tats", "ab", "anl", "an", "coe", "crst", "heu", "abh", "kals", "lmt", "lc", "me", "mic", "ne", "q", "san", "stlb", "stv", "trd", "wrk", "bdy", "cor", "geik", "hem", "herc", "ilm", "oilm", "lime", "mft", "mt", "mang", "bunsn", "per", "pnt", "ru", "sp", "usp", "br", "dsp", "gth", "ank", "arag", "cc", "dol", "mag", "rhc", "sid", "diam", "gph", "iron", "Ni", "CO2", "CO", "H2", "CH4", "O2", "H2O", "abL", "anL", "diL", "enL", "faL", "fliq", "foL", "h2oL", "hliq", "kspL", "mliq", "qL", "silL", "H+", "Cl-", "OH-", "Na+", "K+", "Ca++", "Mg++", "Fe++", "Al+++", "CO3", "AlOH3", "AlOH4-", "KOH", "HCL", "KCL", "NaCl", "CaCl2", "CaCl+", "MgCl2", "MgCl", "FeCl2", "aqSi",)
        full_names = ("akermanite", "almandine", "andalusite", "andradite", "clinohumite", "clinozoisite", "cordierite", "epidote(ordered)", "fayalite", "Fe-chloritoid", "Fe-cordierite", "Fe-epidote", "Fe-osumilite", "Fe-staurolite", "forsterite", "gehlenite", "grossular", "hydrous cordierite", "hydroxy-topaz", "kyanite", "larnite-bredigite", "lawsonite", "merwinite", "Mg-chloritoid", "Mg-staurolite", "Mn-chloritoid", "Mn-cordierite", "Mn-staurolite", "monticellite", "osumilite(1)", "osumilite(2)", "phase A", "pumpellyite", "pyrope", "rankinite", "sillimanite", "spessartine", "sphene", "spurrite", "tephroite", "tilleyite", "vesuvianite", "zircon", "zoisite", "acmite", "Ca-tschermaks pyroxene", "Diopside", "enstatite", "ferrosilite", "hedenbergite", "jadeite", "mg-tschermak", "pseudowollastonite", "pyroxmangite", "rhodonite", "wollastonite", "anthophyllite", "cummingtonite", "Fe-anthophyllite", "Fe-glaucophane", "ferroactinolite", "gedrite(Na-free)", "glaucophane", "grunerite", "pargasite", "riebeckite", "tremolite", "tschermakite", "deerite", "fe-carpholite", "fe-sapphirine(793)", "mg-carpholite", "sapphirine(442)", "sapphirine(793)", "annite", "celadonite", "eastonite", "Fe-celadonite", "margarite", "Mn-biotite", "muscovite", "Na-phlogopite", "paragonite", "phlogopite", "Al-free chlorite", "amesite(14Ang)", "clinochlore(ordered)", "daphnite", "Fe-sudoite", "Mn-chlorite", "Sudoite", "antigorite", "chrysotile", "Fe-talc", "Kaolinite", "prehnite", "pyrophyllite", "talc", "tschermak-talc", "albite", "analcite", "anorthite", "coesite", "cristobalite", "heulandite", "highalbite", "kalsilite", "laumontite", "leucite", "meionite", "microcline", "nepheline", "quartz", "sanidine", "stilbite", "stishovite", "tridymite", "wairakite", "baddeleyite", "corundum", "geikielite", "hematite", "hercynite", "ilmenite", "ilmenite(ordered)", "lime", "magnesioferrite", "magnetite", "manganosite", "nickel oxide", "periclase", "pyrophanite", "rutile", "spinel", "ulvospinel", "brucite", "diaspore", "goethite", "ankerite", "aragonite", "calcite", "dolomite", "magnesite", "rhodochrosite", "siderite", "diamond", "graphite", "iron", "nickel", "carbon dioxide", "carbon monoxide", "hydrogen", "methane", "oxygen", "water fluid", "albite liquid", "anorthite liquid", "diopside liquid", "enstatite liquid", "fayalite liquid", "Fe-liquid (in KFMASH)", "Forsterite liquid", "H2O liquid", "H2O liquid (in KFMASH)", "K-feldspar liquid", "Mg liquid (in KFMASH)", "Silica liquid", "Sillimanite liquid", "H+(aq)", "Cl(aq)", "OH(aq)", "Na+(aq)", "K+(aq)", "Ca2+(aq)", "Mg2+(aq)", "Fe2+(aq)", "Al3+(aq)", "CO3--(aq)", "Al(OH)3(aq)", "Al(OH)4----(aq)", "KOH(aq)", "HCl(aq)", "KCl(aq)", "NaCl(aq)", "CaCl(aq)", "CaCl+(aq)", "MgCl2(aq)", "MgCl+(aq)", "FeCl(aq)", "Aqueous silica",)
        t = name .== full_names
        if any(t)
            abbreviations[findfirst(t)]
        else
            name
        end
    end
    export perplex_abbreviate_name

    function perplex_common_name(name)
        abbreviations = ("ak", "alm", "and", "andr", "chum", "cz", "crd", "ep", "fa", "fctd", "fcrd", "fep", "fosm", "fst", "fo", "geh", "gr", "hcrd", "tpz", "ky", "larn", "law", "merw", "mctd", "mst", "mnctd", "mncrd", "mnst", "mont", "osm1", "osm2", "phA", "pump", "py", "rnk", "sill", "spss", "sph", "spu", "teph", "ty", "vsv", "zrc", "zo", "acm", "cats", "di", "en", "fs", "hed", "jd", "mgts", "pswo", "pxmn", "rhod", "wo", "anth", "cumm", "fanth", "fgl", "ftr", "ged", "gl", "grun", "parg", "rieb", "tr", "ts", "deer", "fcar", "fspr", "mcar", "spr4", "spr7", "ann", "cel", "east", "fcel", "ma", "mnbi", "mu", "naph", "pa", "phl", "afchl", "ames", "clin", "daph", "fsud", "mnchl", "sud", "atg", "chr", "fta", "kao", "pre", "prl", "ta", "tats", "ab", "anl", "an", "coe", "crst", "heu", "abh", "kals", "lmt", "lc", "me", "mic", "ne", "q", "san", "stlb", "stv", "trd", "wrk", "bdy", "cor", "geik", "hem", "herc", "ilm", "oilm", "lime", "mft", "mt", "mang", "bunsn", "per", "pnt", "ru", "sp", "usp", "br", "dsp", "gth", "ank", "arag", "cc", "dol", "mag", "rhc", "sid", "diam", "gph", "iron", "Ni", "CO2", "CO", "H2", "CH4", "O2", "H2O", "abL", "anL", "diL", "enL", "faL", "fliq", "foL", "h2oL", "hliq", "kspL", "mliq", "qL", "silL", "H+", "Cl-", "OH-", "Na+", "K+", "Ca++", "Mg++", "Fe++", "Al+++", "CO3", "AlOH3", "AlOH4-", "KOH", "HCL", "KCL", "NaCl", "CaCl2", "CaCl+", "MgCl2", "MgCl", "FeCl2", "aqSi", "Aqfl(HGP)", "Cpx(HGP)", "Augite(G)", "Cpx(JH)", "Cpx(l)", "Cpx(h)", "Cpx(stx)", "Cpx(stx7)", "Omph(HP)", "Cpx(HP)", "Cpx(m)", "Cpx(stx8)", "Cps(HGP)", "Omph(GHP)", "cAmph(G)", "Cumm", "Gl", "Tr", "GlTrTsPg", "Amph(DHP)", "Amph(DPW)", "Ca-Amph(D)", "Na-Amph(D)", "Act(M)", "GlTrTsMr", "cAmph(DP)", "melt(HGPH)", "melt(G)", "melt(W)", "melt(HP)", "melt(HGP)", "pMELTS(G)", "mMELTS(G)", "LIQ(NK)", "LIQ(EF)", "Chl(W)", "Chl(HP)", "Chl(LWV)", "O(HGP)","O(JH)", "O(SG)", "O(HP)", "O(HPK)", "O(stx)", "O(stx7)", "Ol(m)", "O(stx8)", "Sp(HGP)", "Sp(JH)", "GaHcSp", "Sp(JR)", "Sp(GS)", "Sp(HP)", "Sp(stx)", "CrSp", "Sp(stx7)", "Sp(WPC)", "Sp(stx8)", "Pl(JH)", "Pl(h)", "Pl(stx8)", "Kf", "San", "San(TH)", "Gt(HGP)", "Grt(JH)", "Gt(W)", "CrGt", "Gt(MPF)", "Gt(B)", "Gt(GCT)", "Gt(HP)", "Gt(EWHP)", "Gt(WPH)", "Gt(stx)", "Gt(stx8)", "Gt(WPPH)", "ZrGt(KP)", "Maj", "Opx(HGP)", "Opx(JH)", "Opx(W)", "Opx(HP)", "CrOpx(HP)", "Opx(stx)", "Opx(stx8)", "Mica(W)", "Pheng(HP)", "MaPa", "Mica(CF)", "Mica(CHA1)", "Mica(CHA)", "Mica+(CHA)", "Mica(M)", "Mica(SGH)", "Ctd(W)", "Ctd(HP)", "Ctd(SGH)", "St(W)", "St(HP)", "Bi(HGP)", "Bi(W)", "Bio(TCC)", "Bio(WPH)", "Bio(HP)", "Crd(W)", "hCrd", "Sa(WP)", "Sapp(HP)", "Sapp(KWP)", "Sapp(TP)", "Osm(HP)", "F", "F(salt)", "COH-Fluid", "Aq_solven0", "WADDAH", "T", "Scap", "Carp", "Carp(M)", "Carp(SGH)", "Sud(Livi)", "Sud", "Sud(M)", "Anth", "o-Amph", "oAmph(DP)", "feldspar", "feldspar_B", "Pl(I1,HP)", "Fsp(C1)", "Do(HP)", "M(HP)", "Do(AE)", "Cc(AE)", "oCcM(HP)", "Carb(M)", "oCcM(EF)", "dis(EF)", "IlHm(A)", "IlGkPy", "Ilm(WPH)", "Ilm(WPH0)", "Neph(FB)", "Chum", "Atg(PN)", "B", "Pu(M)", "Stlp(M)", "Wus",)
        common_names = ("akermanite", "almandine", "andalusite", "andradite", "clinohumite", "clinozoisite", "cordierite", "epidote", "fayalite", "Fe-chloritoid", "Fe-cordierite", "Fe-epidote", "Fe-osumilite", "Fe-staurolite", "forsterite", "gehlenite", "grossular", "hydrous cordierite", "hydroxy-topaz", "kyanite", "larnite", "lawsonite", "merwinite", "Mg-chloritoid", "Mg-staurolite", "Mn-chloritoid", "Mn-cordierite", "Mn-staurolite", "monticellite", "osumilite(1)", "osumilite(2)", "phase A", "pumpellyite", "pyrope", "rankinite", "sillimanite", "spessartine", "sphene", "spurrite", "tephroite", "tilleyite", "vesuvianite", "zircon", "zoisite", "acmite", "Ca-tschermakite", "diopside", "enstatite", "ferrosilite", "hedenbergite", "jadeite", "Mg-tschermakite", "pseudowollastonite", "pyroxmangite", "rhodonite", "wollastonite", "anthophyllite", "cummingtonite", "Fe-anthophyllite", "Fe-glaucophane", "ferroactinolite", "gedrite", "glaucophane", "grunerite", "pargasite", "riebeckite", "tremolite", "tschermakite", "deerite", "Fe-carpholite", "Fe-sapphirine(793)", "Mg-carpholite", "sapphirine(442)", "sapphirine(793)", "annite", "celadonite", "eastonite", "Fe-celadonite", "margarite", "Mn-biotite", "muscovite", "Na-phlogopite", "paragonite", "phlogopite", "Al-free chlorite", "amesite", "clinochlore", "daphnite", "Fe-sudoite", "Mn-chlorite", "sudoite", "antigorite", "chrysotile", "Fe-talc", "kaolinite", "prehnite", "pyrophyllite", "talc", "tschermak-talc", "albite", "analcite", "anorthite", "coesite", "cristobalite", "heulandite", "highalbite", "kalsilite", "laumontite", "leucite", "meionite", "microcline", "nepheline", "quartz", "sanidine", "stilbite", "stishovite", "tridymite", "wairakite", "baddeleyite", "corundum", "geikielite", "hematite", "hercynite", "ilmenite", "ilmenite(ordered)", "lime", "magnesioferrite", "magnetite", "manganosite", "nickel oxide", "periclase", "pyrophanite", "rutile", "spinel", "ulvospinel", "brucite", "diaspore", "goethite", "ankerite", "aragonite", "calcite", "dolomite", "magnesite", "rhodochrosite", "siderite", "diamond", "graphite", "iron", "nickel", "carbon dioxide", "carbon monoxide", "hydrogen", "methane", "oxygen", "water fluid", "albite liquid", "anorthite liquid", "diopside liquid", "enstatite liquid", "fayalite liquid", "Fe-liquid (in KFMASH)", "forsterite liquid", "H2O liquid", "H2O liquid (in KFMASH)", "K-feldspar liquid", "Mg liquid (in KFMASH)", "Silica liquid", "Sillimanite liquid", "H+(aq)", "Cl(aq)", "OH(aq)", "Na+(aq)", "K+(aq)", "Ca2+(aq)", "Mg2+(aq)", "Fe2+(aq)", "Al3+(aq)", "CO3--(aq)", "Al(OH)3(aq)", "Al(OH)4----(aq)", "KOH(aq)", "HCl(aq)", "KCl(aq)", "NaCl(aq)", "CaCl(aq)", "CaCl+(aq)", "MgCl2(aq)", "MgCl+(aq)", "FeCl(aq)", "Aqueous silica", "Aqueous fluid", "clinopyroxene", "clinopyroxene", "clinopyroxene", "clinopyroxene", "clinopyroxene", "clinopyroxene", "clinopyroxene", "clinopyroxene", "clinopyroxene", "clinopyroxene", "clinopyroxene", "clinopyroxene", "clinopyroxene", "clinoamphibole", "clinoamphibole", "clinoamphibole", "clinoamphibole", "clinoamphibole", "clinoamphibole", "clinoamphibole", "clinoamphibole", "clinoamphibole", "clinoamphibole", "clinoamphibole", "clinoamphibole", "melt", "melt", "melt", "melt", "melt", "melt", "melt", "melt", "melt", "chlorite", "chlorite", "chlorite", "olivine", "olivine", "olivine", "olivine", "olivine", "olivine", "olivine", "olivine", "olivine", "spinel", "spinel", "spinel", "spinel", "spinel", "spinel", "spinel", "spinel", "spinel", "spinel", "spinel", "plagioclase", "plagioclase", "plagioclase", "k-feldspar", "k-feldspar", "k-feldspar", "garnet", "garnet", "garnet", "garnet", "garnet", "garnet", "garnet", "garnet", "garnet", "garnet", "garnet", "garnet", "garnet", "garnet", "garnet", "orthopyroxene", "orthopyroxene", "orthopyroxene", "orthopyroxene", "orthopyroxene", "orthopyroxene", "orthopyroxene", "white mica", "white mica", "white mica", "white mica", "white mica", "white mica", "white mica", "white mica", "white mica", "chloritoid", "chloritoid", "chloritoid", "staurolite", "staurolite", "biotite", "biotite", "biotite", "biotite", "biotite", "cordierite", "cordierite", "sapphirine", "sapphirine", "sapphirine", "sapphirine", "osumilite", "fluid", "fluid", "fluid", "fluid", "fluid", "talc", "scapolite", "carpholite", "carpholite", "carpholite", "sudoite", "sudoite", "sudoite", "orthoamphibole", "orthoamphibole", "orthoamphibole", "ternary feldspar", "ternary feldspar", "ternary feldspar", "ternary feldspar", "calcite", "calcite", "calcite", "calcite", "calcite", "calcite", "calcite", "calcite", "ilmenite", "ilmenite", "ilmenite", "ilmenite", "nepheline", "clinohumite", "serpentine", "brucite", "pumpellyite", "stilpnomelane", "wüstite",)
        t = name .== abbreviations
        if any(t)
            common_names[findfirst(t)]
        elseif contains(name,"anorthite")
            "anorthite"
        elseif contains(name,"albite")
            "albite"
        elseif contains(name,"orthoclase")
            "orthoclase"
        else
            name
        end
    end
    export perplex_common_name


## -- Zircon saturation calculations

    """
    ```julia
    M = Boehnke_tzircM(SiO2, TiO2, Al2O3, FeOT, MnO, MgO, CaO, Na2O, K2O, P2O5)
    ```
    Calculate zircon saturation M-value based on major element concentrations
    Following the zircon saturation calibration of Boehnke, Watson, et al., 2013
    (doi: 10.1016/j.chemgeo.2013.05.028)
    """
    function Boehnke_tzircM(SiO2::Number, TiO2::Number, Al2O3::Number, FeOT::Number, MnO::Number, MgO::Number, CaO::Number, Na2O::Number, K2O::Number, P2O5::Number)
        #Cations
        Na = Na2O/30.9895
        K = K2O/47.0827
        Ca = CaO/56.0774
        Al = Al2O3/50.9806
        Si = SiO2/60.0843
        Ti = TiO2/79.865
        Fe = FeOT/71.8444
        Mg = MgO/24.3050
        Mn = MnO/70.9374
        P = P2O5/70.9723

        # Normalize cation fractions
        normconst = nansum((Na, K, Ca, Al, Si, Ti, Fe, Mg, Mn, P))
        K, Na, Ca, Al, Si = (K, Na, Ca, Al, Si) ./ normconst

        M = (Na + K + 2*Ca)/(Al * Si)
        return M
    end
    function Boehnke_tzircM(SiO2::AbstractArray, TiO2::AbstractArray, Al2O3::AbstractArray, FeOT::AbstractArray, MnO::AbstractArray, MgO::AbstractArray, CaO::AbstractArray, Na2O::AbstractArray, K2O::AbstractArray, P2O5::AbstractArray)
        #Cations
        Na = Na2O/30.9895
        K = K2O/47.0827
        Ca = CaO/56.0774
        Al = Al2O3/50.9806
        Si = SiO2/60.0843
        Ti = TiO2/79.865
        Fe = FeOT/71.8444
        Mg = MgO/24.3050
        Mn = MnO/70.9374
        P = P2O5/70.9723

        # Normalize cation fractions
        normconst = nansum([Na K Ca Al Si Ti Fe Mg Mn P], dim=2)
        K .= K ./ normconst
        Na .= Na ./ normconst
        Ca .= Ca ./ normconst
        Al .= Al ./ normconst
        Si .= Si ./ normconst

        M = (Na + K + 2*Ca)./(Al .* Si)
        return M
    end
    export Boehnke_tzircM
    tzircM = Boehnke_tzircM
    export tzircM

    """
    ```julia
    ZrSat = Boehnke_tzircZr(SiO2, TiO2, Al2O3, FeOT, MnO, MgO, CaO, Na2O, K2O, P2O5, T)
    ```
    Calculate zircon saturation Zr concentration for a given temperature (in C)
    Following the zircon saturation calibration of Boehnke, Watson, et al., 2013
    (doi: 10.1016/j.chemgeo.2013.05.028)
    """
    function Boehnke_tzircZr(SiO2, TiO2, Al2O3, FeOT, MnO, MgO, CaO, Na2O, K2O, P2O5, T)
        M = Boehnke_tzircM(SiO2, TiO2, Al2O3, FeOT, MnO, MgO, CaO, Na2O, K2O, P2O5)
        # Boehnke, Watson, et al., 2013
        ZrSat = @. max(496000. /(exp(10108. /(T+273.15) -0.32 -1.16*M)), 0)
        return ZrSat
    end
    export Boehnke_tzircZr
    tzircZr = Boehnke_tzircZr
    export tzircZr

    """
    ```julia
    T = Boehnke_tzirc(SiO2, TiO2, Al2O3, FeOT, MnO, MgO, CaO, Na2O, K2O, P2O5, Zr)
    ```
    Calculate zircon saturation temperature in degrees Celsius
    Following the zircon saturation calibration of Boehnke, Watson, et al., 2013
    (doi: 10.1016/j.chemgeo.2013.05.028)
    """
    function Boehnke_tzirc(SiO2, TiO2, Al2O3, FeOT, MnO, MgO, CaO, Na2O, K2O, P2O5, Zr)
        M = Boehnke_tzircM(SiO2, TiO2, Al2O3, FeOT, MnO, MgO, CaO, Na2O, K2O, P2O5)
        # Boehnke, Watson, et al., 2013
        TC = @. 10108. / (0.32 + 1.16*M + log(496000. / Zr)) - 273.15
        return TC
    end
    export Boehnke_tzirc
    tzirc = Boehnke_tzirc
    export tzirc


## --- Sphene saturation calculations

    function Ayers_tspheneC(SiO2::Number, TiO2::Number, Al2O3::Number, FeOT::Number, MnO::Number, MgO::Number, CaO::Number, Na2O::Number, K2O::Number, P2O5::Number)
        #Cations
        Na = Na2O/30.9895
        K = K2O/47.0827
        Ca = CaO/56.0774
        Al = Al2O3/50.9806
        Si = SiO2/60.0843
        Ti = TiO2/79.865
        Fe = FeOT/71.8444
        Mg = MgO/24.3050
        Mn = MnO/70.9374
        P = P2O5/70.9723

        # Normalize cation fractions
        normconst = nansum((Na, K, Ca, Al, Si, Ti, Fe, Mg, Mn, P))
        K, Na, Ca, Al, Si = (K, Na, Ca, Al, Si) ./ normconst

        eCa = Ca - Al/2 + Na/2 + K/2
        return (10 * eCa) / (Al * Si)
    end

    """
    ```julia
    TiO2Sat = Ayers_tspheneTiO2(SiO2, TiO2, Al2O3, FeOT, MnO, MgO, CaO, Na2O, K2O, P2O5, T)
    ```
    Calculate sphene saturation TiO2 concentration (in wt. %) for a given temperature
    (in C) following the sphene saturation calibration of Ayers et al., 2018
    (doi: 10.1130/abs/2018AM-320568)
    """
    function Ayers_tspheneTiO2(SiO2, TiO2, Al2O3, FeOT, MnO, MgO, CaO, Na2O, K2O, P2O5, TC)
        C = Ayers_tspheneC(SiO2, TiO2, Al2O3, FeOT, MnO, MgO, CaO, Na2O, K2O, P2O5)
        TiO2 = max(0.79*C - 7993/(TC+273.15) + 7.88, 0)
        return TiO2
    end
    export Ayers_tspheneTiO2


    """
    ```julia
    TC = Ayers_tsphene(SiO2, TiO2, Al2O3, FeOT, MnO, MgO, CaO, Na2O, K2O, P2O5)
    ```
    Calculate sphene saturation temperature in degrees Celsius
    Following the sphene saturation calibration of Ayers et al., 2018
    (doi: 10.1130/abs/2018AM-320568)
    """
    function Ayers_tsphene(SiO2, TiO2, Al2O3, FeOT, MnO, MgO, CaO, Na2O, K2O, P2O5)
        C = Ayers_tspheneC(SiO2, TiO2, Al2O3, FeOT, MnO, MgO, CaO, Na2O, K2O, P2O5)
        TC = 7993/(0.79*C - TiO2 + 7.88) - 273.15
        return TC
    end
    export Ayers_tsphene

## --- Rutile saturation calculations

    function FM(SiO2::Number, TiO2::Number, Al2O3::Number, FeOT::Number, MgO::Number, CaO::Number, Na2O::Number, K2O::Number, P2O5::Number)
        #Cations
        Na = Na2O/30.9895
        K = K2O/47.0827
        Ca = CaO/56.0774
        Al = Al2O3/50.9806
        Si = SiO2/60.0843
        Ti = TiO2/79.865
        Fe = FeOT/71.8444
        Mg = MgO/24.3050
        P = P2O5/70.9723

        # Normalize cation fractions
        normconst = nansum((Na, K, Ca, Al, Si, Ti, Fe, Mg, P))
        Na, K, Ca, Mg, Fe, Al, Si = (Na, K, Ca, Mg, Fe, Al, Si) ./ normconst

        return (Na + K + 2(Ca + Mg + Fe)) / (Al * Si)
    end


    """
    ```julia
    TC = Hayden_trutile(SiO2, TiO2, Al2O3, FeOT, MgO, CaO, Na2O, K2O, P2O5)
    ```
    Calculate rutile saturation temperature in degrees Celcius
    following the rutile saturation model of Hayden and Watson, 2007
    (doi: 10.1016/j.epsl.2007.04.020)
    """
    function Hayden_trutile(SiO2::Number, TiO2::Number, Al2O3::Number, FeOT::Number, MgO::Number, CaO::Number, Na2O::Number, K2O::Number, P2O5::Number)
        TK = 5305.0 / (7.95 - log10(TiO2 * 10000 * 47.867/(47.867+15.999*2)) + 0.124*FM(SiO2, TiO2, Al2O3, FeOT, MgO, CaO, Na2O, K2O, P2O5))
        TC = TK - 273.15
    end

    """
    ```julia
    TC = Hayden_trutile(SiO2, TiO2, Al2O3, FeOT, MgO, CaO, Na2O, K2O, P2O5, TC)
    ```
    Calculate the TiO2 concentration in weight percent required for rutile
    saturation at temperature `TC` degrees Celcius, following the rutile
    saturation model of Hayden and Watson, 2007
    (doi: 10.1016/j.epsl.2007.04.020)
    """
    function Hayden_trutileTiO2(SiO2::Number, TiO2::Number, Al2O3::Number, FeOT::Number, MgO::Number, CaO::Number, Na2O::Number, K2O::Number, P2O5::Number, TC::Number)
        TK = TC + 273.15
        return exp10(7.95 - 5315.0/TK + 0.124*FM(SiO2, TiO2, Al2O3, FeOT, MgO, CaO, Na2O, K2O, P2O5)) * (47.867+15.999*2)/47.867 * 1e-5
    end


## --- Monazite and xenotime saturation calculations

    """
    ```julia
    LREEmolwt(La, Ce, Pr, Nd, Sm, Gd)
    ```
    Returns the average molecular weight of the LREE considered in the
    REEt value from the monazite saturation model of Montel 1993
    (doi: 10.1016/0009-2541(93)90250-M)
    """
    function LREEmolwt(La, Ce, Pr, Nd, Sm, Gd)
        # All as PPM
        nansum((138.905477La, 140.1161Ce, 140.907662Pr, 144.2423Nd, 150.362Sm, 157.253Gd)) / nansum((La, Ce, Pr, Nd, Sm, Gd))
    end

    """
    ```julia
    LREEt(La, Ce, Pr, Nd, Sm, Gd)
    ```
    Returns the sum of the LREE concentrations divided by their respective molar masses.
    If REE are input in parts per million by weight (ppmw), the result is in units of moles per megagram.
    This is equivalent to the REEt value from the monazite saturation model of Montel 1993
    (doi: 10.1016/0009-2541(93)90250-M)
    """
    function LREEt(La::T, Ce::T, Pr::T, Nd::T, Sm::T, Gd::T) where T <: Number
        # All as PPM
        nansum((La/138.905477, Ce/140.1161, Pr/140.907662, Nd/144.2423, Sm/150.362, Gd/157.253))
    end


    function Montel_tmonaziteD(SiO2::T, TiO2::T, Al2O3::T, FeOT::T, MgO::T, CaO::T, Na2O::T, K2O::T, Li2O::T, H2O::T) where T <: Number
        #Cations
        H = H2O/9.0075
        Li = Li2O/14.9395
        Na = Na2O/30.9895
        K = K2O/47.0827
        Ca = CaO/56.0774
        Al = Al2O3/50.9806
        Si = SiO2/60.0843
        Ti = TiO2/79.865
        Fe = FeOT/71.8444
        Mg = MgO/24.3050
        # Anions
        # O = 0.5H + 0.5Li + 0.5Na + 0.5K + Ca + Mg + Fe + 1.5Al + 2Si + 2Ti

        # Calculate cation fractions
        normconst = nansum((H, Li, Na, K, Ca, Al, Si, Ti, Fe, Mg))
        Li, Na, K, Ca, Al, Si = (Li, Na, K, Ca, Al, Si) ./ normconst

        # Note that the paper incorrectly describes this equation as being
        # written in terms of atomic percent ("at.%"), but in fact it appears
        # to require molar cation fractions, just as does the analagous M-value
        # equation found in zircon saturation papers
        D = (Na + K + Li + 2Ca) / (Al * (Al + Si))
        return D
    end

    """
    ```julia
    REEt = Montel_tmonaziteREE(SiO2, TiO2, Al2O3, FeOT, MgO, CaO, Na2O, K2O, Li2O, H2O, T)
    ```
    Calculate monazite saturation REEt value (in [ppm/mol.wt.]) for a given
    temperature (in C) following the monazite saturation model of Montel 1993
    (doi: 10.1016/0009-2541(93)90250-M), where:

    D = (Na + K + Li + 2Ca) / Al * 1/(Al + Si)) # all as molar cation fractions (not at. %!)
    ln(REEt) = 9.50 + 2.34D + 0.3879√H2O - 13318/T # H2O as wt.%
    REEt = Σ REEᵢ(ppm) / at. weight (g/mol)
    """
    function Montel_tmonaziteREE(SiO2, TiO2, Al2O3, FeOT, MgO, CaO, Na2O, K2O, Li2O, H2O, T)
        D = Montel_tmonaziteD(SiO2, TiO2, Al2O3, FeOT, MgO, CaO, Na2O, K2O, Li2O, H2O) # input as wt. %
        REEt = exp(9.50 + 2.34*D + 0.3879*sqrt(H2O) - 13318/(T+272.15))
        return REEt
    end
    export Montel_tmonaziteREE

    """
    ```julia
    TC = Montel_tmonazite(SiO2, TiO2, Al2O3, FeOT, MgO, CaO, Na2O, K2O, Li2O, H2O, La, Ce, Pr, Nd, Sm, Gd)
    ```
    Calculate monazite saturation temperature in degrees Celcius
    following the monazite saturation model of Montel 1993
    (doi: 10.1016/0009-2541(93)90250-M)
    """
    function Montel_tmonazite(SiO2, TiO2, Al2O3, FeOT, MgO, CaO, Na2O, K2O, Li2O, H2O, La, Ce, Pr, Nd, Sm, Gd)
        D = Montel_tmonaziteD(SiO2, TiO2, Al2O3, FeOT, MgO, CaO, Na2O, K2O, Li2O, H2O) # input as wt. %
        REEt = LREEt(La, Ce, Pr, Nd, Sm, Gd) # input in PPM
        TC = 13318/(9.50 + 2.34*D + 0.3879*sqrt(H2O) - log(REEt)) - 272.15
        return TC
    end
    export Montel_tmonazite


    """
    ```julia
    LREEt = Rusiecka_tmonaziteREE(P_ppm, TC)
    ```
    Calculate the LREEt (mol/Megagram) value required for monazite saturation at a
    temperature of `TC` degrees celcius and `P` ppmw phosphorous present,
    following the solubility model of Rusiecka & Baker, 2019
    (doi: 10.2138/am-2019-6931)
    """
    function Rusiecka_tmonaziteREE(P_ppm, TC)
        #[LREE][P] (mol^2/100g^2) = 10^(2.3055 - 1.029e4/T)
        Kₛₚ = 10^(2.3055 - 1.029e4/(TC + 273.15))
        LREE_μmol_g = Kₛₚ/(P_ppm/10000/30.97)*10000
        return LREE_μmol_g
    end

    """
    ```julia
    LREEt = Rusiecka_txenotimeY(P_ppm, TC)
    ```
    Calculate the Y (ppmw) concentration required for xenotime saturation at a
    temperature of `TC` degrees celcius and `P` ppmw phosphorous present,
    following the solubility model of Rusiecka & Baker, 2019
    (doi: 10.2138/am-2019-6931)
    """
    function Rusiecka_txenotimeY(P_ppm, TC)
        # [Y][P] (mol^2/100g^2) = 10^(3.6932 - 1.1469e4/T)
        Kₛₚ = 10^(3.6932 - 1.1469e4/(TC + 273.15))
        Y_ppm = Kₛₚ/(P_ppm/10000/30.97)*10000*88.905
        return Y_ppm
    end

## --- Apatite saturation calculations

    """
    ```julia
    P2O5 = Harrison_tapatiteP2O5(SiO2, Al2O3, CaO, Na2O, K2O, T)
    ```
    Calculate `P2O5` concentration (in wt.%) required for apatite saturation at a
    given `T` (in C) following the apatite saturation model of Harrison and Watson
    1984 (doi: 10.1016/0016-7037(84)90403-4) with the correction of Bea et al. 1992
    (doi: 10.1016/0024-4937(92)90033-U) where applicable
    """
    function Harrison_tapatiteP2O5(SiO2::T, Al2O3::T, CaO::T, Na2O::T, K2O::T, TC::T) where T <: Number
        TK = TC + 273.16
        ASI = (Al2O3/50.9806)/(CaO/56.0774 + Na2O/30.9895 + K2O/47.0827)
        P2O5sat = 52.5525567/exp( (8400 + 2.64e4(SiO2/100 - 0.5))/TK - (3.1 + 12.4(SiO2/100 - 0.5)) )
        return max(P2O5sat, P2O5sat * (ASI-1) * 6429/TK)
    end
    function Harrison_tapatiteP2O5(SiO2::T, TC::T) where T <: Number
        TK = TC + 273.16
        P2O5sat = 52.5525567/exp( (8400 + 2.64e4(SiO2/100 - 0.5))/TK - (3.1 + 12.4(SiO2/100 - 0.5)) )
        return P2O5sat
    end
    export Harrison_tapatiteP2O5

    """
    As `Harrison_tapatiteP2O5`, but returns saturation phosphorus concentration in PPM P
    """
    Harrison_tapatiteP(x...) = Harrison_tapatiteP2O5(x...) * 10_000 / 2.2913349
    export Harrison_tapatiteP

    """
    ```julia
    TC = Harrison_tapatite(SiO2, P2O5)
    ```
    Calculate apatite saturation temperature in degrees Celcius
    following the apatite saturation model of Harrison and Watson 1984
    (doi: 10.1016/0016-7037(84)90403-4)
    """
    function Harrison_tapatite(SiO2::T, P2O5::T) where T <: Number
        TK = (8400 + 2.64e4(SiO2/100 - 0.5)) / (log(52.5525567/P2O5) + (3.1 + 12.4(SiO2/100 - 0.5)))
        return TK - 273.16
    end
    export Harrison_tapatite

    """
    ```julia
    P2O5 = Tollari_tapatiteP2O5(SiO2, CaO, T)
    ```
    Calculate `P2O5` concentration (in wt.%) required for apatite saturation at a
    given `T` (in C) following the apatite saturation model of Tollari et al. 2006
    (doi: 10.1016/j.gca.2005.11.024)
    """
    function Tollari_tapatiteP2O5(SiO2::T, CaO::T, TC::T) where T <: Number
        # Using conversions from Tollari et al.
        SiO2ₘ = 1.11 * SiO2
        CaOₘ = 1.18 * CaO
        TK = TC+273.15
        P2O5satₘ = exp(TK * (-0.8579/(139.0 - SiO2ₘ) + 0.0165)  -  10/3*log(CaOₘ))
        return P2O5satₘ / 0.47
    end

    """
    ```julia
    TC = Tollari_tapatite(SiO2, TiO2, Al2O3, FeOT, MgO, CaO, Na2O, K2O, P2O5)
    ```
    Calculate apatite saturation temperature in degrees Celcius
    following the apatite saturation model of Tollari et al. 2006
    (doi: 10.1016/j.gca.2005.11.024)
    """
    function Tollari_tapatite(SiO2, TiO2, Al2O3, FeOT, MgO, CaO, Na2O, K2O, P2O5)
        # Cations
        Na2 = Na2O/61.97854
        K2 = K2O/94.19562
        Ca = CaO/56.0774
        Al2 = Al2O3/101.960077
        Si = SiO2/60.0843
        Ti = TiO2/79.865
        Fe = FeOT/71.8444
        Mg = MgO/24.3050
        P2 = P2O5/141.94252

        # Normalize to mole percent oxides
        normconst = nansum((Na2, K2, Ca, Al2, Si, Ti, Fe, Mg, P2))
        CaOₘ = Ca / normconst * 100
        SiO2ₘ = Si / normconst * 100
        P2O5ₘ = P2 / normconst * 100
        TC = (log(P2O5ₘ) + 10/3*log(CaOₘ)) / (-0.8579/(139.0 - SiO2ₘ) + 0.0165) - 273.15
        return TC
    end

## --- Ti-in-zircon thermometry

    """
    ```julia
    Ti = Ferry_Ti_in_zircon(TC::Number, aSiO2::Number, aTiO2::Number)
    ```
    Parts per million by weight of titanium in zircon at temperature `TC` degrees
    Celsius given `aSiO2` silica activity and `aTiO2` titanium activity, following
    the equations of Ferry and Watson, 2007.
    (doi: 10.1007/s00410-007-0201-0)
    """
    function Ferry_Ti_in_zircon(TC::Number, aSiO2::Number, aTiO2::Number)
        exp10(5.711 - 4800.0/(TC+273.15) - log10(aSiO2) +log10(aTiO2))
    end

    """
    ```julia
    Ti = Crisp_Ti_in_zircon(TC::Number, Pbar::Number, aSiO2::Number, aTiO2::Number)
    ```
    Parts per million by weight of titanium in zircon at temperature `TC` degrees
    Celsius and pressure `Pbar` bar given `aSiO2` silica activity and `aTiO2`
    titanium activity, following the equations of Crisp et al., 2023.
    (doi: 10.1016/j.gca.2023.04.031)
    """
    function Crisp_Ti_in_zircon(TC::Number, Pbar::Number, aSiO2::Number, aTiO2::Number)
        T = TC+273.15
        P = Pbar*1e-4
        f = 1.0/(1.0+10.0^(0.775P - 3.3713))
        exp10(5.84 - 4800.0/T - 0.12*P - 0.0056*P^3 - log10(aSiO2)*f +log10(aTiO2)) / f
    end


    """
    ```julia
    Ti = Ferry_Zr_in_rutile(TC::Number, aSiO2::Number)
    ```
    Parts per million by weight of zirconium in rutile at temperature `TC`
    degrees Celsius given `aSiO2` silica activity, following the
    equations of Ferry and Watson, 2007.
    (doi: 10.1007/s00410-007-0201-0)
    """
    function Ferry_Zr_in_rutile(TC::Number, aSiO2::Number)
        exp10(7.420 - 4530.0/(TC+273.15) - log10(aSiO2))
    end

## --- End of File

## --- CRUST 1.0

    """
    ```julia
    get_crust1()
    ```
    Download CRUST 1.0 data and references.
    """
    function get_crust1()
        # Construct file paths
        filedir = joinpath(resourcepath,"crust1")
        referencepath = joinpath(filedir,"crust1.references.txt")
        vppath = joinpath(filedir,"crust1.vp")
        vspath = joinpath(filedir,"crust1.vs")
        rhopath = joinpath(filedir,"crust1.rho")
        bndpath = joinpath(filedir,"crust1.bnds")

        # Download HDF5 file from Google Cloud if necessary
        if ~isfile(referencepath)
            @info "Downloading crust1 files from google cloud storage to $filedir"
            run(`mkdir -p $filedir`)
            Downloads.download("https://storage.googleapis.com/statgeochem/crust1.references.txt", referencepath)
            Downloads.download("https://storage.googleapis.com/statgeochem/crust1.vp", vppath)
            Downloads.download("https://storage.googleapis.com/statgeochem/crust1.vs", vspath)
            Downloads.download("https://storage.googleapis.com/statgeochem/crust1.rho", rhopath)
            Downloads.download("https://storage.googleapis.com/statgeochem/crust1.bnds", bndpath)
        end

        return 0 # Success
    end
    export get_crust1

    """
    ```julia
    find_crust1_layer(lat,lon,layer)
    ```
    Return all point data (Vp, Vs, Rho, layer thickness) for a given `lat`itude,
    `lon`gitude, and crustal `layer`.

    Accepts `lat` and `lon` both as `Numbers` and as `AbstractArray`s, but given
    the overhead of opening and reading the crust1 files, you should generally
    aim to provide large arrays with as many values in a single query as possible.

    Available `layer`s:
    `1`) water
    `2`) ice
    `3`) upper sediments   (VP, VS, rho not defined in all cells)
    `4`) middle sediments  "
    `5`) lower sediments   "
    `6`) upper crystalline crust
    `7`) middle crystalline crust
    `8`) lower crystalline crust
    Results are returned in form `(Vp, Vs, Rho, thickness)`

    ## Examples
    ```julia
    julia> vp, vs, rho, thickness = find_crust1_layer([43.702245], [-72.0929], 8)
    ([7.0], [3.99], [2950.0], [7.699999999999999])
    ```
    """
    function find_crust1_layer(lat,lon,layer)
        # Get Vp, Vs, Rho, and thickness for a given lat, lon, and crustal layer.
        @assert eachindex(lat) == eachindex(lon)


        if ~isa(layer,Integer) || layer < 1 || layer > 8
            error("""Error: layer must be an integer between 1 and 8.
            Available layers:
            1) water
            2) ice
            3) upper sediments   (VP, VS, rho not defined in all cells)
            4) middle sediments  "
            5) lower sediments   "
            6) upper crystalline crust
            7) middle crystalline crust
            8) lower crystalline crust
            Results are returned in form (Vp, Vs, Rho, thickness)
            """)
        end

        nlayers=9
        nlon=360
        nlat=180

        # Allocate data arrays
        vp = Array{Float64,3}(undef,nlayers,nlat,nlon)
        vs = Array{Float64,3}(undef,nlayers,nlat,nlon)
        rho = Array{Float64,3}(undef,nlayers,nlat,nlon)
        bnd = Array{Float64,3}(undef,nlayers,nlat,nlon)

        # Open data files
        vpfile = open(joinpath(resourcepath,"crust1","crust1.vp"), "r")
        vsfile = open(joinpath(resourcepath,"crust1","crust1.vs"), "r")
        rhofile = open(joinpath(resourcepath,"crust1","crust1.rho"), "r")
        bndfile = open(joinpath(resourcepath,"crust1","crust1.bnds"), "r")

        # Read data files into array
        for j=1:nlat
           for i=1:nlon
              vp[:,j,i] = delim_string_parse(readline(vpfile), ' ', Float64, merge=true)
              vs[:,j,i] = delim_string_parse(readline(vsfile), ' ', Float64, merge=true)
              rho[:,j,i] = delim_string_parse(readline(rhofile), ' ', Float64, merge=true) * 1000 # convert to kg/m3
              bnd[:,j,i] = delim_string_parse(readline(bndfile), ' ', Float64, merge=true)
          end
        end

        # Close data files
        close(vpfile)
        close(vsfile)
        close(rhofile)
        close(bndfile)

        # Allocate output arrays
        vpout = Array{Float64}(undef,size(lat))
        vsout = Array{Float64}(undef,size(lat))
        rhoout = Array{Float64}(undef,size(lat))
        thkout = Array{Float64}(undef,size(lat))

        # Fill output arrays
        @inbounds for j ∈ eachindex(lat)
            # Avoid edge cases at lat = -90.0, lon = 180.0
            lonⱼ = mod(lon[j] + 180, 360) - 180
            latⱼ = lat[j]

            if -90 < latⱼ < 90 && -180 < lonⱼ < 180
                # Convert lat and lon to index
                ilat = 91 - ceil(Int,latⱼ)
                ilon = 181 + floor(Int,lonⱼ)

                vpout[j] = vp[layer,ilat,ilon]
                vsout[j] = vs[layer,ilat,ilon]
                rhoout[j] = rho[layer,ilat,ilon]
                thkout[j] = bnd[layer,ilat,ilon] - bnd[layer+1,ilat,ilon]
            else
                vpout[j] = NaN
                vsout[j] = NaN
                rhoout[j] = NaN
                thkout[j] = NaN
            end
        end

        # The end
        return (vpout, vsout, rhoout, thkout)
    end
    export find_crust1_layer

    """
    ```julia
    find_crust1_seismic(lat,lon,layer)
    ```
    Return all seismic data (Vp, Vs, Rho) for a given `lat`itude, `lon`gitude,
    and crustal `layer`.

    Accepts `lat` and `lon` both as `Numbers` and as `AbstractArray`s, but given
    the overhead of opening and reading the crust1 files, you should generally
    aim to provide large arrays with as many values in a single query as possible.

    Available `layer`s:
    `1`) water
    `2`) ice
    `3`) upper sediments   (VP, VS, rho not defined in all cells)
    `4`) middle sediments  "
    `5`) lower sediments   "
    `6`) upper crystalline crust
    `7`) middle crystalline crust
    `8`) lower crystalline crust
    Results are returned in form `(Vp, Vs, Rho, thickness)`

    ## Examples
    ```julia
    julia> vp, vs, rho = find_crust1_seismic([43.702245], [-72.0929], 8)
    ([7.0], [3.99], [2950.0])
    ```
    """
    function find_crust1_seismic(lat,lon,layer)
        # Vp, Vs, and Rho for a given lat, lon, and crustal layer.
        @assert eachindex(lat) == eachindex(lon)

        if ~isa(layer,Integer) || layer < 1 || layer > 9
            error("""Error: layer must be an integer between 1 and 9.
            Available layers:
            1) water
            2) ice
            3) upper sediments   (VP, VS, rho not defined in all cells)
            4) middle sediments  "
            5) lower sediments   "
            6) upper crystalline crust
            7) middle crystalline crust
            8) lower crystalline crust
            9) Top of mantle below crust
            Results are returned in form (Vp, Vs, Rho)
            """)
        end

        nlayers=9
        nlon=360
        nlat=180

        # Allocate data arrays
        vp = Array{Float64,3}(undef,nlayers,nlat,nlon)
        vs = Array{Float64,3}(undef,nlayers,nlat,nlon)
        rho = Array{Float64,3}(undef,nlayers,nlat,nlon)

        # Open data files
        vpfile = open(joinpath(resourcepath,"crust1","crust1.vp"), "r")
        vsfile = open(joinpath(resourcepath,"crust1","crust1.vs"), "r")
        rhofile = open(joinpath(resourcepath,"crust1","crust1.rho"), "r")

        # Read data files into array
        for j=1:nlat
           for i=1:nlon
              vp[:,j,i] = delim_string_parse(readline(vpfile), ' ', Float64, merge=true)
              vs[:,j,i] = delim_string_parse(readline(vsfile), ' ', Float64, merge=true)
              rho[:,j,i] = delim_string_parse(readline(rhofile), ' ', Float64, merge=true) * 1000 # convert to kg/m3
          end
        end

        # Close data files
        close(vpfile)
        close(vsfile)
        close(rhofile)

        # Allocate output arrays
        vpout = Array{Float64}(undef,size(lat))
        vsout = Array{Float64}(undef,size(lat))
        rhoout = Array{Float64}(undef,size(lat))

        # Fill output arrays
        @inbounds for j ∈ eachindex(lat)
            # Avoid edge cases at lat = -90.0, lon = 180.0
            lonⱼ = mod(lon[j] + 180, 360) - 180
            latⱼ = lat[j]

            if -90 < latⱼ < 90 && -180 < lonⱼ < 180
                # Convert lat and lon to index
                ilat = 91 - ceil(Int,latⱼ)
                ilon = 181 + floor(Int,lonⱼ)

                vpout[j] = vp[layer,ilat,ilon]
                vsout[j] = vs[layer,ilat,ilon]
                rhoout[j] = rho[layer,ilat,ilon]
            else
                vpout[j] = NaN
                vsout[j] = NaN
                rhoout[j] = NaN
            end
        end

        # The end
        return (vpout, vsout, rhoout)
    end
    export find_crust1_seismic

    """
    ```julia
    find_crust1_thickness(lat,lon,layer)
    ```
    Return layer thickness for a crust 1.0 `layer` at a given `lat`itude and
    `lon`gitude.

    Accepts `lat` and `lon` both as `Numbers` and as `AbstractArray`s, but given
    the overhead of opening and reading the crust1 files, you should generally
    aim to provide large arrays with as many values in a single query as possible.

    Available `layer`s:
    `1`) water
    `2`) ice
    `3`) upper sediments   (VP, VS, rho not defined in all cells)
    `4`) middle sediments  "
    `5`) lower sediments   "
    `6`) upper crystalline crust
    `7`) middle crystalline crust
    `8`) lower crystalline crust
    Results are returned in form `(Vp, Vs, Rho, thickness)`

    ## Examples
    ```julia
    julia> find_crust1_thickness([43.702245], [-72.0929], 8)
    1-element Vector{Float64}:
     7.699999999999999
    ```
    """
    function find_crust1_thickness(lat,lon,layer)
        # Layer thickness for a given lat, lon, and crustal layer.
        @assert eachindex(lat) == eachindex(lon)

        if ~isa(layer,Integer) || layer < 1 || layer > 8
            error("""Error: layer must be an integer between 1 and 8.
            Available layers:
            1) water
            2) ice
            3) upper sediments   (VP, VS, rho not defined in all cells)
            4) middle sediments  "
            5) lower sediments   "
            6) upper crystalline crust
            7) middle crystalline crust
            8) lower crystalline crust
            Result is thickness of the requested layer
            """)
        end

        nlayers=9
        nlon=360
        nlat=180

        # Allocate data arrays
        bnd = Array{Float64,3}(undef,nlayers,nlat,nlon)

        # Open data files
        bndfile = open(joinpath(resourcepath,"crust1","crust1.bnds"), "r")

        # Read data files into array
        for j=1:nlat
           for i=1:nlon
              bnd[:,j,i] = delim_string_parse(readline(bndfile), ' ', Float64, merge=true)
          end
        end

        # Close data files
        close(bndfile)

        # Allocate output arrays
        thkout = Array{Float64}(undef,size(lat))

        # Fill output arrays
        @inbounds for j ∈ eachindex(lat)
            # Avoid edge cases at lat = -90.0, lon = 180.0
            lonⱼ = mod(lon[j] + 180, 360) - 180
            latⱼ = lat[j]

            if -90 < latⱼ < 90 && -180 < lonⱼ < 180
                # Convert lat and lon to index
                ilat = 91 - ceil(Int,latⱼ)
                ilon = 181 + floor(Int,lonⱼ)

                thkout[j] = bnd[layer,ilat,ilon]-bnd[layer+1,ilat,ilon]
            else
                thkout[j] = NaN
            end
        end

        # The end
        return thkout
    end
    export find_crust1_thickness

    """
    ```julia
    find_crust1_base(lat,lon,layer)
    ```
    Return elevation (relative to sea level) of the layer base for a crust 1.0
    `layer` at a given `lat`itude and `lon`gitude.

    Accepts `lat` and `lon` both as `Numbers` and as `AbstractArray`s, but given
    the overhead of opening and reading the crust1 files, you should generally
    aim to provide large arrays with as many values in a single query as possible.

    Available `layer`s:
    `1`) water
    `2`) ice
    `3`) upper sediments   (VP, VS, rho not defined in all cells)
    `4`) middle sediments  "
    `5`) lower sediments   "
    `6`) upper crystalline crust
    `7`) middle crystalline crust
    `8`) lower crystalline crust
    Results are returned in form `(Vp, Vs, Rho, thickness)`

    ## Examples
    ```julia
    julia> find_crust1_base([43.702245], [-72.0929], 8)
    1-element Vector{Float64}:
     -36.26
    ```
    """
    function find_crust1_base(lat,lon,layer)
        # Depth to layer base for a given lat, lon, and crustal layer.
        @assert eachindex(lat) == eachindex(lon)


        if ~isa(layer,Integer) || layer < 1 || layer > 8
            error("""layer must be an integer between 1 and 8.
            Available layers:
            1) water
            2) ice
            3) upper sediments   (VP, VS, rho not defined in all cells)
            4) middle sediments  "
            5) lower sediments   "
            6) upper crystalline crust
            7) middle crystalline crust
            8) lower crystalline crust
            Result is depth from sea level to base of the requested layer
            """)
        end
        nlayers=9
        nlon=360
        nlat=180

        # Allocate data arrays
        bnd = Array{Float64,3}(undef,nlayers,nlat,nlon)

        # Open data files
        bndfile = open(joinpath(resourcepath,"crust1","crust1.bnds"), "r")

        # Read data files into array
        for j=1:nlat
           for i=1:nlon
              bnd[:,j,i] = delim_string_parse(readline(bndfile), ' ', Float64, merge=true)
          end
        end

        # Close data files
        close(bndfile)

        # Allocate output arrays
        baseout = Array{Float64}(undef,size(lat))

        # Fill output arrays
        @inbounds for j ∈ eachindex(lat)
            # Avoid edge cases at lat = -90.0, lon = 180.0
            lonⱼ = mod(lon[j] + 180, 360) - 180
            latⱼ = lat[j]

            if -90 < latⱼ < 90 && -180 < lonⱼ < 180
                # Convert lat and lon to index
                ilat = 91 - ceil(Int,latⱼ)
                ilon = 181 + floor(Int,lonⱼ)

                baseout[j] = bnd[layer+1,ilat,ilon]
            else
                baseout[j] = NaN
            end
        end

        # The end
        return baseout
    end
    export find_crust1_base

## --- End of File

## --- Land

    """
    ```julia
    find_land(lat,lon)
    ```
    Find whether or not a given set of `lat`itude, `lon`gitude points on the globe
    is above sea level, based on the `etopo` bedrock elevation dataset

    ## Examples
    ```julia
    julia> find_land(43.702245, -72.0929)
    0-dimensional Array{Bool, 0}:
    1
    ```
    """
    function find_land(lat, lon)
        # Interpret user input
        @assert eachindex(lat) == eachindex(lon)
        filepath = artifact"land/land.h5"
        land = h5read(filepath, "vars/land")

        # Scale factor (cells per degree) = 30 = arc minutes in an arc degree
        sf = 30
        maxrow = 180 * sf
        maxcol = 360 * sf

        # Create and fill output vector
        result = zeros(Bool, size(lat))
        for i ∈ eachindex(lat)
            if (-90 <= lat[i] <= 90) && (-180 <= lon[i] < 180)
                # Convert latitude and longitude into indicies of the elevation map array
                row = 1 + trunc(Int,(90+lat[i])*sf)
                row == (maxrow+1) && (row = maxrow) # Edge case

                col = 1 + trunc(Int,(180+lon[i])*sf)
                col == (maxcol+1) && (col = maxcol) # Edge case

                # Find result by indexing
                result[i] = land[row,col]
            end
        end

        return result
    end
    export find_land

## --- Geolcont

    continentcolors = parse.(Color, ["#333399","#0066CC","#06A9C1","#66CC66","#FFCC33","#FFFF00","#FFFFFF"])
    export continentcolors

    continents = ["Africa","Eurasia","North America","South America","Australia","Antarctica","NA"]
    export continents

    """
    ```julia
    find_geolcont(lat,lon)
    ```
    Find which geographic continent a sample originates from.

    Continents:
    ```
      1: "Africa"
      2: "Eurasia"
      3: "North America"
      4: "South America"
      5: "Australia"
      6: "Antarctica"
      7: "NA"
    ```

    See also: `continents`, `continentcolors`.

    ## Examples
    ```julia
    julia> find_geolcont(43.702245, -72.0929)
    0-dimensional Array{Int64, 0}:
    3

    julia> continents[find_geolcont(43.702245, -72.0929)]
    0-dimensional Array{String, 0}:
    "North America"
    ```
    """
    function find_geolcont(lat,lon)
        @assert eachindex(lat) == eachindex(lon)

        # Construct file path
        filepath = artifact"geolcont/geolcontwshelf.png"

        img = load(filepath)

        ind = fill(7,size(img))
        for i=1:6
            ind[img .== continentcolors[i]] .= i
        end

        # Create and fill output vector
        contindex = Array{Int}(undef,size(lat))
        for i ∈ eachindex(lat)
            if (-90 <= lat[i] <= 90) && (-180 <= lon[i] <= 180)
                # Convert latitude and longitude into indicies of the elevation map array
                # Note that STRTM15 plus has N+1 columns where N = 360*sf
                row = 1 + trunc(Int,(90-lat[i])*512/180)
                col = 1 + trunc(Int,(180+lon[i])*512/180)
                # Find result by indexing
                contindex[i] = ind[row,col]
            else
                # Result is unknown if either input is NaN or out of bounds
                contindex[i] = 7
            end
        end

        return contindex
    end
    export find_geolcont


## --- geolprov

    """
    ```julia
    find_geolprov(lat,lon)
    ```
    Find which tectonic setting a sample originates from, based on a modified version
    of the USGS map of tectonic provinces of the world
    (c.f. https://commons.wikimedia.org/wiki/File:World_geologic_provinces.jpg)

    Settings:
    ```
      10: Accreted Arc
      11: Island Arc
      12: Continental Arc
      13: Collisional orogen
      20: Extensional
      21: Rift
      22: Plume
      31: Shield
      32: Platform
      33: Basin
      00: No data
    ```

    Settings returned are most representative modern setting at a given location
    and may not represent the tectonic setting where rocks (especially older/Precambrian
    rocks) originally formed.

    ## Examples
    ```julia
    julia> find_geolprov(43.702245, -72.0929)
    0-dimensional Array{Int64, 0}:
    10

    julia> lat = rand(4)*180 .- 90
    4-element Vector{Float64}:
     -28.352224011759773
      14.521710123066882
      43.301961981794335
      79.26368353708557

    julia> lon = rand(4)*360 .- 180
    4-element Vector{Float64}:
       5.024149409750521
     161.04362679392233
     123.21726489255786
     -54.34797401313695

    julia> find_geolprov(lat, lon)
    4-element Vector{Int64}:
      0
      0
     32
      0
    ```
    """
    function find_geolprov(lat, lon)
        @assert eachindex(lat) == eachindex(lon)
        filepath = artifact"geolprov/geolprov.h5"
        geolprov = h5read(filepath, "geolprov")

        result = zeros(Int, size(lat))
        for i ∈ eachindex(lat)
            if -180 < lon[i] <= 180 && -90 <= lat[i] < 90
                x = ceil(Int, (lon[i]+180) * 2161/360)
                y = ceil(Int, (90-lat[i]) * 1801/180)
                result[i] = geolprov[y,x]
            end
        end
        return result
    end
    export find_geolprov

## --- ETOPO1 (1 arc minute topography)

"""
```julia
get_etopo([varname])
```
Read ETOPO1 (1 arc minute topography) file from HDF5 storage, downloading
from cloud if necessary.

Available `varname`s (variable names) include:
```
  "elevation"
  "y_lat_cntr"
  "x_lon_cntr"
  "cellsize"
  "scalefactor"
  "reference"
```

Units are meters of elevation and decimal degrees of latitude and longitude.

Reference:
Amante, C. and B.W. Eakins, 2009. ETOPO1 1 Arc-Minute Global Relief Model:
Procedures, Data Sources and Analysis. NOAA Technical Memorandum NESDIS NGDC-24.
National Geophysical Data Center, NOAA. doi:10.7289/V5C8276M.
http://www.ngdc.noaa.gov/mgg/global/global.html

See also: `find_etopoelev`.

## Examples
```julia
julia> get_etopo()
Dict{String, Any} with 6 entries:
  "cellsize"    => 0.0166667
  "scalefactor" => 60
  "x_lon_cntr"  => [-179.992, -179.975, -179.958, -179.942, -179.925, -1…
  "reference"   => "Amante, C. and B.W. Eakins, 2009. ETOPO1 1 Arc-Minut…
  "y_lat_cntr"  => [-89.9917, -89.975, -89.9583, -89.9417, -89.925, -89.…
  "elevation"   => [-58.0 -58.0 … -58.0 -58.0; -61.0 -61.0 … -61.0 -61.0…

julia> get_etopo("elevation")
10800×21600 Matrix{Float64}:
  -58.0    -58.0    -58.0  …    -58.0    -58.0    -58.0
  -61.0    -61.0    -61.0       -61.0    -61.0    -61.0
  -62.0    -63.0    -63.0       -63.0    -63.0    -62.0
  -61.0    -62.0    -62.0       -62.0    -62.0    -61.0
    ⋮                      ⋱
 -4226.0  -4226.0  -4227.0     -4227.0  -4227.0  -4227.0
 -4228.0  -4228.0  -4229.0     -4229.0  -4229.0  -4229.0
 -4229.0  -4229.0  -4229.0     -4229.0  -4229.0  -4229.0
```
"""
function get_etopo(varname="")
    # Available variable names: "elevation", "y_lat_cntr", "x_lon_cntr",
    # "cellsize", "scalefactor", and "reference". Units are meters of
    # elevation and decimal degrees of latitude and longitude

    # Construct file path
    filedir = joinpath(resourcepath,"etopo")
    filepath = joinpath(filedir,"etopo1.h5")

    # Download HDF5 file from Google Cloud if necessary
    if ~isfile(filepath)
        @info "Downloading etopo1.h5 from google cloud storage to $filedir"
        run(`mkdir -p $filedir`)
        Downloads.download("https://storage.googleapis.com/statgeochem/etopo1.references.txt", joinpath(filedir,"etopo1.references.txt"))
        Downloads.download("https://storage.googleapis.com/statgeochem/etopo1.h5", filepath)
    end

    # Read and return the file
    return h5read(filepath, "vars/"*varname)
end
export get_etopo


"""
```julia
find_etopoelev([etopo], lat, lon, [T=Float64])
```
Find the elevation of points at position (`lat`, `lon`) on the surface of the
Earth, using the ETOPO1 one-arc-degree elevation model.

Units are meters of elevation and decimal degrees of latitude and longitude.

Reference:
Amante, C. and B.W. Eakins, 2009. ETOPO1 1 Arc-Minute Global Relief Model:
Procedures, Data Sources and Analysis. NOAA Technical Memorandum NESDIS NGDC-24.
National Geophysical Data Center, NOAA. doi:10.7289/V5C8276M.
http://www.ngdc.noaa.gov/mgg/global/global.html

See also: `get_etopo`.

## Examples
```julia
julia> etopo = get_etopo("elevation")
10800×21600 Matrix{Float64}:
   -58.0    -58.0    -58.0  …    -58.0    -58.0    -58.0
   -61.0    -61.0    -61.0       -61.0    -61.0    -61.0
   -62.0    -63.0    -63.0       -63.0    -63.0    -62.0
   -61.0    -62.0    -62.0       -62.0    -62.0    -61.0
     ⋮                      ⋱
 -4226.0  -4226.0  -4227.0     -4227.0  -4227.0  -4227.0
 -4228.0  -4228.0  -4229.0     -4229.0  -4229.0  -4229.0
 -4229.0  -4229.0  -4229.0     -4229.0  -4229.0  -4229.0

julia> find_etopoelev(etopo, 43.702245, -72.0929)
0-dimensional Array{Float64, 0}:
294.0
```
"""
find_etopoelev(lat,lon) = find_etopoelev(get_etopo(),lat,lon)
find_etopoelev(etopo::Dict, lat, lon) = find_etopoelev(etopo["elevation"], lat, lon)
function find_etopoelev(etopo::AbstractArray, lat, lon, T=Float64)
    # Interpret user input
    @assert eachindex(lat) == eachindex(lon)

    # Scale factor (cells per degree) = 60 = arc minutes in an arc degree
    sf = 60
    maxrow = 180 * sf
    maxcol = 360 * sf

    # Create and fill output vector
    result = Array{T}(undef,size(lat))
    for i ∈ eachindex(lat)
        if (-90 <= lat[i] <= 90) && (-180 <= lon[i] <= 180)
            # Convert latitude and longitude into indicies of the elevation map array
            row = 1 + trunc(Int,(90+lat[i])*sf)
            row == (maxrow+1) && (row = maxrow)  # Edge case

            col = 1 + trunc(Int,(180+lon[i])*sf)
            col == (maxcol+1) && (col = maxcol) # Edge case

            # Find result by indexing
            result[i] = etopo[row,col]
        else
            # Result is NaN if either input is NaN or out of bounds
            result[i] = NaN
        end
    end

    return result
end
export find_etopoelev


## --- SRTM15_PLUS (15 arc second topography)

"""
```julia
get_srtm15plus([varname])
```
Read SRTM15plus file from HDF5 storage (15 arc second topography from the
Shuttle Radar Topography Mission), downloading from cloud if necessary.

Available `varname`s (variable names) include:
```
  "elevation"
  "y_lat_cntr"
  "x_lon_cntr"
  "cellsize"
  "scalefactor"
  "nanval"
  "reference"
```
Units are meters of elevation and decimal degrees of latitude and longitude.

Reference: https://doi.org/10.5069/G92R3PT9

See also: `find_srtm15plus`.

## Examples
```julia
julia> get_srtm15plus()
Dict{String, Any} with 7 entries:
  "cellsize"    => 0.00416667
  "scalefactor" => 240
  "x_lon_cntr"  => [-180.0, -179.996, -179.992, -179.988, -179.983,…
  "reference"   => "http://topex.ucsd.edu/WWW_html/srtm30_plus.html"
  "y_lat_cntr"  => [-90.0, -89.9958, -89.9917, -89.9875, -89.9833, …
  "nanval"      => -32768
  "elevation"   => Int16[-32768 -32768 … -32768 -32768; 3124 3124 ……

julia> get_srtm15plus("elevation")
43201×86401 Matrix{Int16}:
 -32768  -32768  -32768  -32768  …  -32768  -32768  -32768
   3124    3124    3124    3124       3113    3113    3124
   3123    3123    3123    3122       3111    3111    3123
   3121    3121    3121    3121       3110    3110    3121
      ⋮                          ⋱                       ⋮
  -4225   -4224   -4224   -4224      -4224   -4225   -4225
  -4223   -4222   -4222   -4223      -4223   -4223   -4223
  -4223   -4223   -4223   -4223      -4223   -4223   -4223
  -4230   -4230   -4230   -4230  …   -4230   -4230   -4230
```
"""
function get_srtm15plus(varname="")
    # Available variable names: "elevation", "y_lat_cntr", "x_lon_cntr",
    # "nanval", "cellsize", "scalefactor", and "reference". Units are
    # meters of elevation and decimal degrees of latitude and longitude

    # Construct file path
    filedir = joinpath(resourcepath,"srtm15plus")
    filepath = joinpath(filedir,"srtm15plus.h5")

    # Download HDF5 file from Google Cloud if necessary
    if ~isfile(filepath)
        @info "Downloading srtm15plus.h5 from google cloud storage to $filedir"
        run(`mkdir -p $filedir`)
        Downloads.download("https://storage.googleapis.com/statgeochem/srtm15plus.references.txt", joinpath(filedir,"srtm15plus.references.txt"))
        Downloads.download("https://storage.googleapis.com/statgeochem/srtm15plus.h5", filepath)
    end

    # Read and return the file
    return h5read(filepath,"vars/"*varname)
end
export get_srtm15plus


"""
```julia
find_srtm15plus([srtm], lat, lon, [T=Float64])
```
Find the elevation of points at position (`lat`, `lon`) on the surface of the
Earth, using the SRTM15plus 15-arc-second elevation model.

Units are meters of elevation and decimal degrees of latitude and longitude.

Reference: https://doi.org/10.5069/G92R3PT9

See also: `get_srtm15plus`.

## Examples
```julia
julia> srtm = get_srtm15plus("elevation")
43201×86401 Matrix{Int16}:
 -32768  -32768  -32768  -32768  …  -32768  -32768  -32768
   3124    3124    3124    3124       3113    3113    3124
   3123    3123    3123    3122       3111    3111    3123
   3121    3121    3121    3121       3110    3110    3121
      ⋮                          ⋱                       ⋮
  -4225   -4224   -4224   -4224      -4224   -4225   -4225
  -4223   -4222   -4222   -4223      -4223   -4223   -4223
  -4223   -4223   -4223   -4223      -4223   -4223   -4223
  -4230   -4230   -4230   -4230  …   -4230   -4230   -4230

julia> find_srtm15plus(srtm, 43.702245, -72.0929)
0-dimensional Array{Float64, 0}:
252.0
```
"""
find_srtm15plus(lat,lon) = find_srtm15plus(get_srtm15plus(),lat,lon)
find_srtm15plus(srtm::Dict, lat, lon) = find_srtm15plus(srtm["elevation"], lat, lon)
function find_srtm15plus(srtm::AbstractArray, lat, lon, T=Float64)
    # Interpret user input
    length(lat) != length(lon) && error("lat and lon must be of equal length")

    # Scale factor (cells per degree) = 60 * 4 = 240
    # (15 arc seconds goes into 1 arc degree 240 times)
    sf = 240

    # Create and fill output vector
    out = Array{T}(undef,size(lat))
    for i ∈ eachindex(lat)
        if isnan(lat[i]) || isnan(lon[i]) || lat[i]>90 || lat[i]<-90 || lon[i]>180 || lon[i]<-180
            # Result is NaN if either input is NaN or out of bounds
            out[i] = NaN
        else
            # Convert latitude and longitude into indicies of the elevation map array
            # Note that STRTM15 plus has N+1 columns where N = 360*sf
            row = 1 + round(Int,(90+lat[i])*sf)
            col = 1 + round(Int,(180+lon[i])*sf)
            # Find result by indexing
            res = srtm[row,col]
            if res == -32768
                out[i] = NaN
            else
                out[i] = res
            end
        end
    end
    return out
end
export find_srtm15plus

## --- End of File
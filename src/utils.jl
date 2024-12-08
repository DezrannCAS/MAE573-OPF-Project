module Utils

using CSV, DataFrames, Plots


"""
    load_data(data_dir::String)

Loads data and returns a dictionary containing bus, branch, plant, load and gencost.
"""
function load_data(data_dir::String; verbose::Bool = true)
    # Load aggregated dataset
    println("Loading data from $data_dir...")
    bus = CSV.read(joinpath(data_dir, "bus.csv"), DataFrame)
    branch = CSV.read(joinpath(data_dir, "branch.csv"), DataFrame)
    plant = CSV.read(joinpath(data_dir, "plant.csv"), DataFrame)
    load = CSV.read(joinpath(data_dir, "load.csv"), DataFrame)
    gencost = CSV.read(joinpath(data_dir, "gencost.csv"), DataFrame)
    
    # Shrink temporal resolution to only 100 datapoints instead of 8784
    load = first(load, 100)

    # Rename columns
    for f in [plant, gencost, branch, bus]
        rename!(f,lowercase.(names(f)))
    end
    rename!(branch, :from_bus_agg => :start_bus, :to_bus_agg => :end_bus)
    rename!(bus, :bus_agg => :bus_id)
    rename!(plant, :bus_agg => :bus_id)

    # Calculate the susceptance of each line
    branch.sus = 1 ./ branch.x 

    # Validate
    @assert "plant_id" ∈ names(plant) "`plant` dataFrame is missing the 'plant_id' column."
    @assert "plant_id" ∈ names(gencost) "`gencost` dataFrame is missing the 'plant_id' column."
    @assert "branch_id" ∈ names(branch) "`branch` dataFrame is missing the 'branch_id' column."
    @assert issetequal(Set(plant.plant_id), Set(gencost.plant_id)) "The set of plant IDs is not the same between `plant` and `gencost`"
    @assert issubset(Set(plant.bus_id), Set(bus.bus_id)) "plant.bus_id is not a subset of bus.bus_id"
    @assert issetequal(union(Set(branch.start_bus), Set(branch.end_bus)), Set(bus.bus_id)) "The union of branch start and end is not equal to the set of bus_id"
    load_bus_set = Set(parse.(Int, filter(s -> all(isdigit, s), names(load))))
    @assert issetequal(union(load_bus_set, Set(plant.bus_id)), Set(bus.bus_id)) "The union of plants and demand nodes is not equal to the set of buses"
    @assert length(unique(plant.plant_id)) == nrow(plant) "The plant_id column contains duplicate values"
    @assert length(unique(branch.branch_id)) == nrow(branch) "The branch_id column contains duplicate values"

    # Add new identifiers (idx always refers to a bus index ranging from 1 to N)
    bus_id_map = Dict(sort(unique(bus.bus_id)) .=> 1:length(unique(bus.bus_id)))
    bus[!, :idx] = [bus_id_map[id] for id in bus.bus_id]
    plant[!, :bus_idx] = [bus_id_map[id] for id in plant.bus_id]
    branch[!, :start_idx] = [bus_id_map[id] for id in branch.start_bus]
    branch[!, :end_idx] = [bus_id_map[id] for id in branch.end_bus]
    
    # Overwrite plant and branch IDs
    plant_id_map = Dict(plant.plant_id .=> 1:nrow(plant))
    plant.plant_id = 1:nrow(plant)
    gencost[!, :plant_id] = [plant_id_map[id] for id in gencost.plant_id]
    branch.branch_id = 1:nrow(branch)

    # Change load data format
    #long_df = stack(load, Not([:date, :time]), variable_name=:bus_id, value_name=:demand)
    #long_df[!, :bus_id] = parse.(Int, long_df[!, :bus_id])
    #long_df[!, :bus_id] = [bus_id_map[id] for id in long_df.bus_id]
    #load = select(long_df, :index, :bus_id, :demand, :date, :time)

    if verbose
        println("\n----- Dataset Information -----\n")
        for (name, df) in [("Bus", bus), ("Branch", branch), ("Plant", plant), ("Load", load), ("Gencost", gencost)]
            println("Dataset: $name")
            println("  Rows: $(size(df, 1))")
            println("  Columns: $(size(df, 2))")
            println("  Column Names: $(names(df))\n")
        end
        println("Number of unique buses: $(length(unique(bus.bus_id))) ($(length(unique(plant.bus_id))) plants, $(ncol(load)-2) demand nodes)")
        println("Number of unique plants: $(length(unique(plant.plant_id)))")
        println("Number of unique branches: $(length(unique(branch.branch_id)))")
        println("\n-------------------------------\n")
    end

    return Dict(
        "bus" => bus,
        "branch" => branch,
        "plant" => plant,
        "load" => load,
        "gencost" => gencost,
    )
end


function plot_results(simulations, metrics)
    println("Plotting results...")

    throw(NotImplementedError("plot_results is not yet implemented."))
end


end
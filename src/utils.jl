module Utils

using CSV, DataFrames, Plots


"""
    load_data(data_dir::String)

Loads data and returns a dictionary containing bus, branch, plant, load and gencost.
"""
function load_data(data_dir::String)
    println("Loading data from $data_dir...")
    bus = CSV.read(joinpath(data_dir, "bus.csv"), DataFrame)
    branch = CSV.read(joinpath(data_dir, "branch.csv"), DataFrame)
    plant = CSV.read(joinpath(data_dir, "plant.csv"), DataFrame)
    load = CSV.read(joinpath(data_dir, "load.csv"), DataFrame)
    gencost = CSV.read(joinpath(data_dir, "gencost.csv"), DataFrame)

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
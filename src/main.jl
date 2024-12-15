# Load modules
include("simulation.jl")
include("optimization.jl")
include("heuristics.jl")
include("utils.jl")

using .Utils
using .DCOPF
using .Simulation
using .Heuristics
using CSV, DataFrames

# Directories
data_dir = "/home/esteban_nb/dirhw/mae573-term-project/data"
output_dir = "/home/esteban_nb/dirhw/mae573-term-project/output"


function load_clean_data()
    clean_data_dir = joinpath(data_dir, "newdata")
    
    bus = CSV.read(joinpath(clean_data_dir, "bus.csv"), DataFrame)
    branch = CSV.read(joinpath(clean_data_dir, "branch.csv"), DataFrame)
    plant = CSV.read(joinpath(clean_data_dir, "plant.csv"), DataFrame)
    load = CSV.read(joinpath(clean_data_dir, "load.csv"), DataFrame)
    gencost = CSV.read(joinpath(clean_data_dir, "gencost.csv"), DataFrame)

    return Dict(
        "bus" => bus,
        "branch" => branch,
        "plant" => plant,
        "load" => load,
        "gencost" => gencost
    )
end

# --------- Criticality assessment ---------

clean_data = load_clean_data()

results = Heuristics.assess_criticality(clean_data)

sorted_results = sort(results_df, :cost_after_removal)

output_file = joinpath(output_dir, "sorted_results.csv")
CSV.write(output_file, sorted_results)[1]
println("CSV file successfully saved at: $output_file")

plot(sorted_results.line, sorted_results.cost_after_removal, 
     xlabel="Branch Line", ylabel="Cost After Removal", 
     title="Criticality of Nodes", 
     label="Cost After Removal", 
     marker=:circle, 
     legend=:topright)
fig_path = joinpath(output_dir, "fig/criticality_plot.png")
savefig(fig_path)
println("Plot successfully saved at: $fig_path")
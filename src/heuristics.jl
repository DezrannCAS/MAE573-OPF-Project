module Heuristics

include("optimization.jl")
using CSV, DataFrames, ProgressMeter
using .DCOPF
export assess_criticality

function assess_criticality(clean_data::Dict)
    # Extract datasets from the input dictionary
    bus = clean_data["bus"]
    branch = clean_data["branch"]
    plant = clean_data["plant"]
    load = clean_data["load"]
    gencost = clean_data["gencost"]

    @assert size(branch, 1) == 470 "We do not have 470 lines (see clean data)"

    results_df = DataFrame(line = Int[], cost_after_removal = Float64[])
    
    println("Executing criticality test...\n")
    p = Progress(length(branch.branch_id), desc="Assessing criticality: ")
    
    for l in branch.branch_id
        println("$l-")
        current_branches = deepcopy(branch)
        current_branches[current_branches.branch_id .== l, :x] .= 1e6

        new_data = Dict(
            "bus" => bus,
            "branch" => current_branches,
            "plant" => plant,
            "load" => load,
            "gencost" => gencost,
        )

        output = DCOPF.perform_optimization(new_data)
        push!(results_df, (l, output.cost))
        
        next!(p)
    end
    return results_df
end

# Write heuristics: select the 10 most critical edges, and take 20 edges, to create a second 
# path between the nodes linked by the critical edges (that goes through a 3rd edge)

end
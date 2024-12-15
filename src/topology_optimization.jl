module OptNet 

include("optimization.jl")
export optimize_network 

using JuMP, Gurobi, DataFrames
using .DCOPF

function optimize_network(
    data::Dict{String, DataFrame}, 
    scenarios::Vector{Dict{String, Float64}}, 
    probabilities::Vector{Float64}, 
    max_modifications::Int64
)
    # Common data
    bus = data["bus"]
    plant = data["plant"]
    load = data["load"]
    gencost = data["gencost"]

    # Branches
    branch = data["branch"]

    candidate_branches = find_candidates(bus, branch)    
    all_branches = vcat(select(branch, [:branch_id, :start_idx, :end_idx]), candidate_branches)
    id2ends_dict = Dict(row.branch_id => (row.start_idx, row.end_idx) for row in eachrow(all_branches))

    # Define sets based on data
    B = sort(branch.branch_id)                  # Set of original branches
    L = sort(candidate_branches.branch_id)      # Set of available links (candidate connections), adjust as needed
    S = 1:length(scenarios)                     # Set of scenarios

    # Extract branch parameters
    x_i = [branch[branch.branch_id .== i, :x] for i in B]       # Reactance of original branches
    r_i = [branch[branch.branch_id .== i, :ratea] for i in B]   # Capacity of original branches

    # Define the JuMP model
    model = Model(Gurobi.Optimizer)

    # Decision variables
    @variable(model, z[i in B], Bin)       # Binary variable for branch removal
    @variable(model, y[j in L], Bin)       # Binary variable for link creation
    @variable(model, x[j in L] >= 0)       # Reactance for a new link
    @variable(model, r[j in L] >= 0)       # Capacity for a new link

    print("Hey! 1")

    # Cost function based on the DCOPF
    function cost_function(z, y, x, r, scenario)
        new_branches = return_branches(z, branch, y, x, r, id2ends_dict)
        new_branches = apply_scenario(new_branches, scenario)
        new_data = Dict(
            "bus" => bus,
            "branch" => new_branches,
            "plant" => plant,
            "load" => load,
            "gencost" => gencost,
        )
        results = DCOPF.perform_optimization(new_data)
        return results.cost
    end

    print("Hey! 2")

    # Objective: Minimize the expected cost over all scenarios
    @expression(model, expected_cost, 
        sum(probabilities[s] * cost_function(z, y, x, r, scenarios[s]) for s in S)
    )
    @objective(model, Min, expected_cost)

    print("Hey! 3")

    # Constraints
    # 1. Link removal and creation balance
    @constraint(model, sum(z[i] for i in B) == sum(y[j] for j in L))

    # 2. Limit on link modifications
    @constraint(model, sum(y[j] for j in L) <= max_modifications)

    # 3. Attribute conservation
    @constraint(model, 
        sum((1 - z[i]) * x_i[i] for i in B) + sum(y[j] * x[j] for j in L) == sum(x_i)
    )
    @constraint(model, 
        sum((1 - z[i]) * r_i[i] for i in B) + sum(y[j] * r[j] for j in L) == sum(r_i)
    )

    # 4. Domain constraints
    @constraint(model, [j in L], x[j] <= 1000 * y[j])  # Enforcing x_j = 0 when y_j = 0
    @constraint(model, [j in L], r[j] <= 1000 * y[j])  # Enforcing r_j = 0 when y_j = 0

    print("Hey! 4")

    # Solve the model
    optimize!(model)

    # Output results
    if termination_status(model) == MOI.OPTIMAL
        return Dict(
            "final_branch" => return_branches(value.(z), value.(y), value.(x), value.(r), id2ends_dict),
            "expected_cost" => objective_value(model)
        )
    else
        error("No optimal solution found.")
    end
end

function find_candidates(bus::DataFrame, branch::DataFrame)
    # Extract bus indices
    bus_indices = bus.idx

    # Get all possible branches (all pairs of bus indices, ordered)
    all_possible_branches = unique([(i, j) for i in bus_indices for j in bus_indices if i != j])  # use i < j for unordered links
    possible_branches_df = DataFrame(
        start_idx = [x[1] for x in all_possible_branches],
        end_idx = [x[2] for x in all_possible_branches]
    )
    candidates = antijoin(possible_branches_df, branch, on = [:start_idx, :end_idx])
    
    # Add branch_id 
    max_branch_id = maximum(branch.branch_id)
    candidates.branch_id = max_branch_id .+ (1:size(candidates, 1))

    return candidates
end

function return_branches(z, branch, y, x, r, id2ends_dict)
    # Create branches from z, y for topology and x, r for attributes
    # 1-z to get existence of line
    # Create the DataFrame
    N = length(z)
    M = N + length(y)

    branch_df = DataFrame(
        branch_id = Int[],
        start_idx = Int[],
        end_idx = Int[],
        x = Int[],
        ratea = Int[]
    )

    for id in 1:M
        if (id <= N && z[id] == 0) || (id > N && y[id] == 1)
            start, end_ = id2ends_dict[id]
            x = id <= N ? branch[findfirst(==(id), branch.id), :x] : x[id - N]
            ratea = id <= N ? branch[branch.id .== id, :ratea] : r[id - N]
            push!(branch_df, (id, start, end_, x, ratea))
        end
    end

    # Calculate the susceptance of each line
    branch_df.sus = 1 ./ branch_df.x 

    return branch_df
end

function apply_scenario(branches, scenario)
    num_lines = size(branches, 1)
    for l in 1:num_lines
        if rand() < scenario["line_failure_prob"]
            branches[l, :x] = 1e6  # set x to a very high value to simulate failure
        end
    end
    return branches
end

end 